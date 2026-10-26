module FTS5Search

using SQLite, DBInterface
using ..Database

struct SearchResult
    chunk_id::String
    source_id::String
    source_version_id::String
    page_number::Union{Int, Nothing}
    title::String
    content::String
    snippet::String
    score::Float64
end

function sanitize_fts_query(raw_query::String)
    clean = replace(raw_query, r"[^\w\s]" => " ")
    words = filter(!isempty, split(clean))
    if isempty(words)
        return ""
    end
    return join(["\"$w\"*" for w in words], " OR ")
end

function search_fts(db::SQLite.DB, workspace_id::String, query_str::String; limit::Int=10)
    fts_query = sanitize_fts_query(query_str)
    if isempty(fts_query)
        return SearchResult[]
    end

    query = """
        SELECT chunk_id, source_id, source_version_id, page_number, title, content,
               snippet(chunks_fts, 6, '<mark>', '</mark>', '...', 25) AS snippet_text,
               bm25(chunks_fts) AS rank_score
        FROM chunks_fts
        WHERE chunks_fts MATCH ? AND workspace_id = ?
        ORDER BY rank_score ASC
        LIMIT ?;
    """

    results = SearchResult[]
    try
        rows = Database.query(db, query, (fts_query, workspace_id, limit))
        for row in rows
            push!(results, SearchResult(
                string(row.chunk_id),
                string(row.source_id),
                string(row.source_version_id),
                ismissing(row.page_number) || row.page_number === nothing ? nothing : Int(row.page_number),
                string(row.title),
                string(row.content),
                string(row.snippet_text),
                abs(Float64(row.rank_score))
            ))
        end
    catch err
        fallback_query = """
            SELECT chunk_id, source_id, source_version_id, page_number, title, content
            FROM chunks_fts
            WHERE content LIKE ? AND workspace_id = ?
            LIMIT ?;
        """
        pattern = "%$(replace(query_str, "%" => ""))%"
        rows = Database.query(db, fallback_query, (pattern, workspace_id, limit))
        for row in rows
            push!(results, SearchResult(
                string(row.chunk_id),
                string(row.source_id),
                string(row.source_version_id),
                ismissing(row.page_number) || row.page_number === nothing ? nothing : Int(row.page_number),
                string(row.title),
                string(row.content),
                string(row.content)[1:min(120, end)],
                1.0
            ))
        end
    end

    return results
end

end # module FTS5Search
