module Assistant

using SQLite, DBInterface, UUIDs, Dates, JSON3
using ..HybridRetriever, ..CitationValidator, ..ProvenanceTracker
using ..Entities, ..Epistemic, ..Database, ..AuditService

struct ConflictReport
    topic::String
    source_a_id::String
    source_a_title::String
    claim_a::String
    citation_a::String
    source_b_id::String
    source_b_title::String
    claim_b::String
    citation_b::String
    explanation::String
end

struct ResearchAnswer
    question::String
    answer::String
    epistemic_state::String
    citations::Vector{CitationValidator.ResolvedCitation}
    conflicts::Vector{ConflictReport}
    limitations::String
    retrieval_trace::Vector{Dict{String, Any}}
end

function ask_research_question(db::SQLite.DB, workspace_id::String, question::String; limit::Int=5)
    evidence_chunks = HybridRetriever.retrieve_grounded_evidence(db, workspace_id, question; limit=limit)
    
    if isempty(evidence_chunks)
        return ResearchAnswer(
            question,
            "Insufficient evidence available in the current workspace to answer this question. No grounded source excerpts matched the inquiry.",
            Epistemic.INSUFFICIENT_EVIDENCE,
            CitationValidator.ResolvedCitation[],
            ConflictReport[],
            "The current document collection does not contain indexed chunks matching this topic.",
            Dict{String, Any}[]
        )
    end

    # Group evidence by source
    sources_involved = Dict{String, Vector{HybridRetriever.GroundedChunk}}()
    for chunk in evidence_chunks
        if !haskey(sources_involved, chunk.source_id)
            sources_involved[chunk.source_id] = HybridRetriever.GroundedChunk[]
        end
        push!(sources_involved[chunk.source_id], chunk)
    end

    # Detect conflicts across distinct sources
    conflicts = ConflictReport[]
    
    rel_sql = """
        SELECT r.source_node_id, r.target_node_id, c1.original_wording AS w1, c2.original_wording AS w2,
               c1.evidence_id AS ev1, c2.evidence_id AS ev2
        FROM relations r
        JOIN claims c1 ON r.source_node_id = c1.id
        JOIN claims c2 ON r.target_node_id = c2.id
        WHERE r.workspace_id = ? AND r.relation_type = 'contradicts';
    """
    rel_rows = Database.query(db, rel_sql, (workspace_id,))
    for row in rel_rows
        ev1 = ismissing(row.ev1) || row.ev1 === nothing ? "" : string(row.ev1)
        ev2 = ismissing(row.ev2) || row.ev2 === nothing ? "" : string(row.ev2)
        q_lower = lowercase(question)
        if any(w -> occursin(w, lowercase(string(row.w1))) || occursin(w, lowercase(string(row.w2))), split(q_lower))
            push!(conflicts, ConflictReport(
                "Contradictory findings in empirical claims",
                "", "", string(row.w1), ev1,
                "", "", string(row.w2), ev2,
                "The collection preserves conflicting claims regarding this subject."
            ))
        end
    end

    # Build synthesis answer text with citations
    answer_parts = String[]
    push!(answer_parts, "Based on the evidence retrieved from your literature collection:")

    for chunk in evidence_chunks
        cite_tag = ProvenanceTracker.format_citation_tag(chunk.source_id, chunk.evidence_id)
        excerpt_summary = strip(replace(chunk.content, '\n' => ' '))
        if length(excerpt_summary) > 280
            excerpt_summary = excerpt_summary[1:280] * "..."
        end
        push!(answer_parts, "\n• $(chunk.title): \"$excerpt_summary\" $cite_tag")
    end

    if !isempty(conflicts)
        push!(answer_parts, "\n\n### Preserved Contradictions & Disagreements")
        for c in conflicts
            push!(answer_parts, "- **Conflict:** $(c.explanation)\n  - Perspective A: \"$(c.claim_a)\"\n  - Perspective B: \"$(c.claim_b)\"")
        end
    end

    raw_answer = join(answer_parts, "\n")

    # Validate citations
    validation_res = CitationValidator.validate_citations(db, workspace_id, raw_answer)

    trace = [
        Dict{String, Any}(
            "chunk_id" => c.chunk_id,
            "source_id" => c.source_id,
            "evidence_id" => c.evidence_id,
            "score" => c.relevance_score,
            "title" => c.title
        )
        for c in evidence_chunks
    ]

    ep_state = !isempty(conflicts) ? Epistemic.CONFLICTED : (validation_res.is_valid ? Epistemic.SOURCE_GROUNDED : Epistemic.AI_INFERRED)
    limitations_text = isempty(conflicts) ? 
        "Synthesis is strictly limited to $(length(evidence_chunks)) retrieved excerpt(s)." :
        "Disagreements exist across sources. Conclusive resolution requires further empirical review."

    return ResearchAnswer(
        question,
        raw_answer,
        ep_state,
        validation_res.citations,
        conflicts,
        limitations_text,
        trace
    )
end

function save_synthesis!(db::SQLite.DB, workspace_id::String, question::String, answer::String, limitations::String, citations::Vector{CitationValidator.ResolvedCitation}; actor::String="user")
    synth_id = string(uuid4())
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    cites_json = JSON3.write(citations)

    synthesis = Entities.Synthesis(synth_id, workspace_id, question, answer, limitations, cites_json, now_iso)

    Database.with_transaction(db) do
        Database.execute(db, """
            INSERT INTO syntheses (id, workspace_id, question, answer, limitations, citation_records, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?);
        """, (synth_id, workspace_id, question, answer, limitations, cites_json, now_iso))

        AuditService.record_audit_event!(
            db, workspace_id, actor, synth_id, "synthesis", "create",
            nothing, JSON3.write(synthesis), "Saved research synthesis for: $question"; correlation_id=synth_id
        )
    end

    return synthesis
end

end # module Assistant
