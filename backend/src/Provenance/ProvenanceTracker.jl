module ProvenanceTracker

using ..Entities

struct CitationReference
    source_id::String
    source_version_id::String
    evidence_id::String
    locator_display::String
    excerpt::String
end

function format_locator(page::Union{Int, Nothing}, start_l::Union{Int, Nothing}, end_l::Union{Int, Nothing})
    parts = String[]
    if page !== nothing
        push!(parts, "p. $page")
    end
    if start_l !== nothing
        if end_l !== nothing && end_l != start_l
            push!(parts, "lines $start_l-$end_l")
        else
            push!(parts, "line $start_l")
        end
    end
    return isempty(parts) ? "unknown locator" : join(parts, ", ")
end

function format_citation_tag(source_id::String, evidence_id::String)
    return "[cite:src:$(source_id)#ev:$(evidence_id)]"
end

function verify_excerpt_in_content(content::String, excerpt::String)
    # Normalized check (trimming excess whitespace)
    norm_content = replace(content, r"\s+" => " ")
    norm_excerpt = replace(strip(excerpt), r"\s+" => " ")
    return occursin(norm_excerpt, norm_content)
end

end # module ProvenanceTracker
