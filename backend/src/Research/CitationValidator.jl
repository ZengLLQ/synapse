module CitationValidator

using SQLite, DBInterface
using ..Entities, ..ProvenanceTracker, ..Database

struct ResolvedCitation
    raw_tag::String
    source_id::String
    evidence_id::String
    source_title::String
    locator::String
    excerpt::String
    is_valid::Bool
    validation_error::Union{String, Nothing}
end

function parse_citation_tags(text::String)
    pattern = r"\[cite:src:([a-zA-Z0-9\-]+)#ev:([a-zA-Z0-9\-]+)\]"
    tags = Tuple{String, String, String}[]
    for m in eachmatch(pattern, text)
        push!(tags, (m.match, m.captures[1], m.captures[2]))
    end
    return tags
end

function validate_citations(db::SQLite.DB, workspace_id::String, text::String)
    tags = parse_citation_tags(text)
    resolved = ResolvedCitation[]

    for (raw, src_id, ev_id) in tags
        # 1. Check source
        src_rows = Database.query(db, "SELECT title FROM sources WHERE id = ? AND workspace_id = ? LIMIT 1;", (src_id, workspace_id))
        if isempty(src_rows)
            push!(resolved, ResolvedCitation(raw, src_id, ev_id, "Unknown Source", "unknown", "", false, "Source ID does not exist in workspace"))
            continue
        end
        source_title = string(first(src_rows).title)

        # 2. Check evidence and verify linkage to source
        ev_query = """
            SELECT e.page_number, e.start_line, e.end_line, e.excerpt
            FROM evidence e
            JOIN source_versions sv ON e.source_version_id = sv.id
            WHERE e.id = ? AND sv.source_id = ?
            LIMIT 1;
        """
        ev_rows = Database.query(db, ev_query, (ev_id, src_id))
        if isempty(ev_rows)
            push!(resolved, ResolvedCitation(raw, src_id, ev_id, source_title, "unlinked", "", false, "Evidence ID does not resolve to a valid version of source"))
            continue
        end

        ev = first(ev_rows)
        p_num = ismissing(ev.page_number) || ev.page_number === nothing ? nothing : Int(ev.page_number)
        s_line = ismissing(ev.start_line) || ev.start_line === nothing ? nothing : Int(ev.start_line)
        e_line = ismissing(ev.end_line) || ev.end_line === nothing ? nothing : Int(ev.end_line)
        locator = ProvenanceTracker.format_locator(p_num, s_line, e_line)
        excerpt = string(ev.excerpt)

        push!(resolved, ResolvedCitation(raw, src_id, ev_id, source_title, locator, excerpt, true, nothing))
    end

    all_valid = !isempty(resolved) && all(c -> c.is_valid, resolved)
    return (is_valid = all_valid, citations = resolved)
end

end # module CitationValidator
