module Entities

using Dates, UUIDs
using ..Epistemic

struct Workspace
    id::String
    name::String
    path::String
    created_at::String
    updated_at::String
    archived::Bool
end

struct Source
    id::String
    workspace_id::String
    title::String
    format::String # 'markdown', 'plaintext', 'pdf'
    checksum::String # SHA-256
    original_path::String
    managed_path::String
    created_at::String
    updated_at::String
end

struct SourceVersion
    id::String
    source_id::String
    version_number::Int
    checksum::String
    total_pages::Int
    total_lines::Int
    total_bytes::Int
    created_at::String
end

struct Evidence
    id::String
    source_version_id::String
    page_number::Union{Int, Nothing}
    start_line::Union{Int, Nothing}
    end_line::Union{Int, Nothing}
    start_char::Union{Int, Nothing}
    end_char::Union{Int, Nothing}
    excerpt::String
    extraction_metadata::String # JSON string
    created_at::String
end

struct Concept
    id::String
    workspace_id::String
    name::String
    description::String
    epistemic_state::String
    evidence_id::Union{String, Nothing}
    created_at::String
    updated_at::String

    function Concept(id, workspace_id, name, description, epistemic_state, evidence_id, created_at, updated_at)
        Epistemic.validate_epistemic_state(epistemic_state)
        new(id, workspace_id, name, description, epistemic_state, evidence_id, created_at, updated_at)
    end
end

struct Claim
    id::String
    workspace_id::String
    original_wording::String
    normalized_claim::String
    epistemic_state::String
    evidence_id::Union{String, Nothing}
    created_at::String
    updated_at::String

    function Claim(id, workspace_id, original_wording, normalized_claim, epistemic_state, evidence_id, created_at, updated_at)
        Epistemic.validate_epistemic_state(epistemic_state)
        new(id, workspace_id, original_wording, normalized_claim, epistemic_state, evidence_id, created_at, updated_at)
    end
end

struct Method
    id::String
    workspace_id::String
    name::String
    description::String
    evidence_id::Union{String, Nothing}
    created_at::String
end

struct Study
    id::String
    workspace_id::String
    title::String
    methodology::String
    findings::String
    evidence_id::Union{String, Nothing}
    created_at::String
end

struct Synthesis
    id::String
    workspace_id::String
    question::String
    answer::String
    limitations::String
    citation_records::String # JSON string containing verified citation objects
    created_at::String
end

end # module Entities
