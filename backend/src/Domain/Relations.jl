module Relations

using ..Epistemic

const SUPPORTS = "supports"
const CONTRADICTS = "contradicts"
const QUALIFIES = "qualifies"
const DERIVED_FROM = "derived_from"
const USES_METHOD = "uses_method"
const EVALUATED_ON = "evaluated_on"
const EXTENDS = "extends"
const RELATED_TO = "related_to"

const VALID_RELATION_TYPES = Set([
    SUPPORTS,
    CONTRADICTS,
    QUALIFIES,
    DERIVED_FROM,
    USES_METHOD,
    EVALUATED_ON,
    EXTENDS,
    RELATED_TO
])

const VALID_NODE_TYPES = Set([
    "concept",
    "claim",
    "method",
    "study",
    "source",
    "synthesis"
])

struct Relation
    id::String
    workspace_id::String
    source_node_id::String
    source_node_type::String
    target_node_id::String
    target_node_type::String
    relation_type::String
    epistemic_state::String
    provenance_id::Union{String, Nothing}
    created_at::String

    function Relation(id, workspace_id, source_node_id, source_node_type, target_node_id, target_node_type, relation_type, epistemic_state, provenance_id, created_at)
        relation_type in VALID_RELATION_TYPES || throw(ArgumentError("Invalid relation type: $relation_type"))
        source_node_type in VALID_NODE_TYPES || throw(ArgumentError("Invalid source node type: $source_node_type"))
        target_node_type in VALID_NODE_TYPES || throw(ArgumentError("Invalid target node type: $target_node_type"))
        Epistemic.validate_epistemic_state(epistemic_state)
        validate_compatibility(source_node_type, target_node_type, relation_type)
        new(id, workspace_id, source_node_id, source_node_type, target_node_id, target_node_type, relation_type, epistemic_state, provenance_id, created_at)
    end
end

function validate_compatibility(src_type::AbstractString, tgt_type::AbstractString, rel_type::AbstractString)
    if rel_type == SUPPORTS || rel_type == CONTRADICTS
        if !(src_type in ["claim", "study", "evidence"] && tgt_type in ["claim", "study"])
            # Allow concept/study relations if grounded
            if !(src_type in ["claim", "concept", "study"] && tgt_type in ["claim", "concept", "study"])
                throw(ArgumentError("Relation $rel_type requires compatible proposition types, got $src_type -> $tgt_type"))
            end
        end
    elseif rel_type == USES_METHOD
        if tgt_type != "method"
            throw(ArgumentError("Relation uses_method must target a method node, got $tgt_type"))
        end
    elseif rel_type == EVALUATED_ON
        if tgt_type != "study"
            throw(ArgumentError("Relation evaluated_on must target a study node, got $tgt_type"))
        end
    end
    return true
end

end # module Relations
