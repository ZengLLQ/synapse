module Routes

using HTTP, JSON3, SQLite, DBInterface, Dates, UUIDs
using ..Entities, ..Epistemic, ..Relations, ..Database
using ..WorkspaceManager, ..SourceService, ..DocumentParsers
using ..Chunking, ..GraphStore, ..GraphQueries, ..FTS5Search
using ..HybridRetriever, ..Assistant, ..CitationValidator
using ..AuditService, ..ReviewQueue, ..JobOrchestrator
using ..CloudConsentGuard, ..MockAdapter, ..WorkspaceExport

function json_response(data::Any; status::Int=200)
    body = JSON3.write(Dict("success" => true, "data" => data, "error" => nothing))
    return HTTP.Response(status, ["Content-Type" => "application/json", "Access-Control-Allow-Origin" => "*", "Access-Control-Allow-Headers" => "*", "Access-Control-Allow-Methods" => "*"], body)
end

function error_response(code::String, message::String; status::Int=400, details::Any=nothing)
    body = JSON3.write(Dict(
        "success" => false,
        "data" => nothing,
        "error" => Dict("code" => code, "message" => message, "details" => details)
    ))
    return HTTP.Response(status, ["Content-Type" => "application/json", "Access-Control-Allow-Origin" => "*", "Access-Control-Allow-Headers" => "*", "Access-Control-Allow-Methods" => "*"], body)
end

function handle_options(req::HTTP.Request)
    return HTTP.Response(204, [
        "Access-Control-Allow-Origin" => "*",
        "Access-Control-Allow-Headers" => "Content-Type, X-Synapse-Token, Authorization",
        "Access-Control-Allow-Methods" => "GET, POST, PUT, DELETE, OPTIONS"
    ], "")
end

# Ingestion Pipeline Helper
function execute_ingestion_pipeline(db::SQLite.DB, workspace_id::String, ws_path::String, file_path::String; title::Union{String, Nothing}=nothing)
    # 1. Import source file and compute checksum
    import_res = SourceService.import_source_file(db, workspace_id, ws_path, file_path; title=title)
    source = import_res.source
    version_id = import_res.version_id

    if import_res.is_duplicate
        return (source = source, is_duplicate = true, message = "File already exists in workspace (checksum matched).")
    end

    # 2. Parse file
    parsed_doc = DocumentParsers.parse_file(source.managed_path)
    
    if parsed_doc.is_scanned
        # Flag scanned PDF without false claim of extraction
        return (source = source, is_duplicate = false, is_scanned = true, warning = parsed_doc.warning)
    end

    # 3. Update source version line / page metadata
    Database.with_transaction(db) do
        Database.execute(db, "UPDATE source_versions SET total_pages = ?, total_lines = ? WHERE id = ?;", (parsed_doc.total_pages, parsed_doc.total_lines, version_id))
    end

    # 4. Chunk & Index FTS5
    chunks = Chunking.chunk_document(parsed_doc, version_id)
    Database.with_transaction(db) do
        Chunking.index_chunks!(db, workspace_id, source.id, chunks)
    end

    # 5. Extract candidate concepts, claims, methods via deterministic MockAdapter
    mock_adapter = MockAdapter.DeterministicMockAdapter()
    candidates = MockAdapter.extract_entities_from_text(mock_adapter, parsed_doc.full_text)

    created_concepts = String[]
    created_claims = String[]

    # Create first evidence record for grounding
    first_ev_id = string(uuid4())
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    first_chunk = isempty(chunks) ? nothing : first(chunks)
    s_line = first_chunk !== nothing ? first_chunk.start_line : 1
    e_line = first_chunk !== nothing ? first_chunk.end_line : 1
    excerpt_sample = first_chunk !== nothing ? first_chunk.content[1:min(300, end)] : ""

    Database.with_transaction(db) do
        Database.execute(db, """
            INSERT INTO evidence (id, source_version_id, page_number, start_line, end_line, start_char, end_char, excerpt, extraction_metadata, created_at)
            VALUES (?, ?, 1, ?, ?, 1, ?, ?, '{"type":"initial_grounding"}', ?);
        """, (first_ev_id, version_id, s_line, e_line, sizeof(excerpt_sample), excerpt_sample, now_iso))
    end

    # Commit extracted entities as AI_INFERRED and stage to review queue
    entity_map = Dict{String, Tuple{String, String}}() # name -> (id, type)

    for cand in candidates
        if cand.type == "concept"
            concept = GraphStore.add_concept!(
                db, workspace_id, cand.name, cand.detail, Epistemic.AI_INFERRED, first_ev_id;
                actor="ai_pipeline"
            )
            ReviewQueue.create_review_item!(db, workspace_id, "concept", concept.id, "Auto-extracted technical concept", cand.confidence)
            push!(created_concepts, concept.id)
            entity_map[cand.name] = (concept.id, "concept")
        elseif cand.type == "method"
            method = GraphStore.add_method!(
                db, workspace_id, cand.name, cand.detail, first_ev_id;
                actor="ai_pipeline"
            )
            ReviewQueue.create_review_item!(db, workspace_id, "method", method.id, "Auto-extracted technical method", cand.confidence)
            entity_map[cand.name] = (method.id, "method")
        elseif cand.type == "claim"
            claim = GraphStore.add_claim!(
                db, workspace_id, cand.original_wording, cand.detail, Epistemic.AI_INFERRED, first_ev_id;
                actor="ai_pipeline"
            )
            ReviewQueue.create_review_item!(db, workspace_id, "claim", claim.id, "Auto-extracted claim proposition", cand.confidence)
            push!(created_claims, claim.id)
            entity_map[cand.name] = (claim.id, "claim")
        end
    end

    # Extract and store relations
    rel_candidates = MockAdapter.extract_relations_from_text(mock_adapter, parsed_doc.full_text, candidates)
    created_relations = String[]

    for rc in rel_candidates
        if haskey(entity_map, rc.source_name) && haskey(entity_map, rc.target_name)
            src_info = entity_map[rc.source_name]
            tgt_info = entity_map[rc.target_name]
            rel = GraphStore.add_relation!(
                db, workspace_id, src_info[1], src_info[2], tgt_info[1], tgt_info[2],
                rc.relation_type, Epistemic.AI_INFERRED, first_ev_id;
                actor="ai_pipeline"
            )
            ReviewQueue.create_review_item!(db, workspace_id, "relation", rel.id, "Auto-extracted relation: $(rc.relation_type)", rc.confidence)
            push!(created_relations, rel.id)
        end
    end

    # Fallback relation if no specific relations extracted but concepts and claims exist
    if isempty(created_relations) && !isempty(created_concepts) && !isempty(created_claims)
        fallback_rel = GraphStore.add_relation!(
            db, workspace_id, first(created_concepts), "concept", first(created_claims), "claim",
            Relations.RELATED_TO, Epistemic.AI_INFERRED, first_ev_id;
            actor="ai_pipeline"
        )
        push!(created_relations, fallback_rel.id)
    end

    return (source = source, is_duplicate = false, chunks_count = length(chunks), concepts = length(created_concepts), claims = length(created_claims), relations = length(created_relations))
end

end # module Routes
