module HybridRetriever

using SQLite, DBInterface, UUIDs, Dates
using ..FTS5Search
using ..Entities, ..Database

struct GroundedChunk
    chunk_id::String
    source_id::String
    source_version_id::String
    evidence_id::String
    page_number::Union{Int, Nothing}
    start_line::Int
    end_line::Int
    start_char::Int
    end_char::Int
    title::String
    content::String
    snippet::String
    relevance_score::Float64
end

function get_or_create_evidence_for_chunk(db::SQLite.DB, chunk_id::String)
    chunk_rows = Database.query(db, "SELECT source_version_id, page_number, start_line, end_line, start_char, end_char, content FROM chunks WHERE id = ? LIMIT 1;", (chunk_id,))
    isempty(chunk_rows) && return nothing
    c = first(chunk_rows)

    src_ver = string(c.source_version_id)
    content = string(c.content)

    ev_rows = Database.query(db, "SELECT id FROM evidence WHERE source_version_id = ? AND start_char = ? AND end_char = ? LIMIT 1;", (src_ver, c.start_char, c.end_char))
    if !isempty(ev_rows)
        return string(first(ev_rows).id)
    end

    new_ev_id = string(uuid4())
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    
    Database.with_transaction(db) do
        ins_sql = """
            INSERT INTO evidence (id, source_version_id, page_number, start_line, end_line, start_char, end_char, excerpt, extraction_metadata, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        Database.execute(db, ins_sql, (
            new_ev_id,
            src_ver,
            ismissing(c.page_number) || c.page_number === nothing ? nothing : c.page_number,
            c.start_line,
            c.end_line,
            c.start_char,
            c.end_char,
            content,
            "{\"type\":\"chunk_grounding\"}",
            now_iso
        ))
    end
    return new_ev_id
end

function retrieve_grounded_evidence(db::SQLite.DB, workspace_id::String, query::String; limit::Int=5)
    fts_results = FTS5Search.search_fts(db, workspace_id, query; limit=limit)
    grounded = GroundedChunk[]

    for r in fts_results
        ev_id = get_or_create_evidence_for_chunk(db, r.chunk_id)
        if ev_id === nothing
            ev_id = string(uuid4())
        end

        c_rows = Database.query(db, "SELECT start_line, end_line, start_char, end_char FROM chunks WHERE id = ? LIMIT 1;", (r.chunk_id,))
        s_line = 1
        e_line = 1
        s_char = 1
        e_char = sizeof(r.content)
        if !isempty(c_rows)
            c = first(c_rows)
            s_line = Int(c.start_line)
            e_line = Int(c.end_line)
            s_char = Int(c.start_char)
            e_char = Int(c.end_char)
        end

        push!(grounded, GroundedChunk(
            r.chunk_id,
            r.source_id,
            r.source_version_id,
            ev_id,
            r.page_number,
            s_line,
            e_line,
            s_char,
            e_char,
            r.title,
            r.content,
            r.snippet,
            r.score
        ))
    end

    return grounded
end

end # module HybridRetriever
