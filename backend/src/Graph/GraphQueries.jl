module GraphQueries

using SQLite, DBInterface
using ..Entities, ..Relations, ..Database

struct GraphNode
    id::String
    type::String
    label::String
    description::String
    epistemic_state::String
    evidence_id::Union{String, Nothing}
    metadata::Dict{String, Any}
end

struct GraphEdge
    id::String
    source::String
    source_type::String
    target::String
    target_type::String
    relation_type::String
    epistemic_state::String
    provenance_id::Union{String, Nothing}
end

struct GraphData
    nodes::Vector{GraphNode}
    edges::Vector{GraphEdge}
end

function get_full_graph(db::SQLite.DB, workspace_id::String; limit::Int=200)
    nodes = GraphNode[]
    edges = GraphEdge[]
    seen_ids = Set{String}()

    # Concepts
    concept_rows = Database.query(db, "SELECT id, name, description, epistemic_state, evidence_id FROM concepts WHERE workspace_id = ? LIMIT ?;", (workspace_id, limit))
    for row in concept_rows
        id = string(row.id)
        push!(seen_ids, id)
        push!(nodes, GraphNode(
            id, "concept", string(row.name), string(row.description), string(row.epistemic_state),
            ismissing(row.evidence_id) || row.evidence_id === nothing ? nothing : string(row.evidence_id), Dict{String, Any}()
        ))
    end

    # Claims
    claim_rows = Database.query(db, "SELECT id, original_wording, normalized_claim, epistemic_state, evidence_id FROM claims WHERE workspace_id = ? LIMIT ?;", (workspace_id, limit))
    for row in claim_rows
        id = string(row.id)
        push!(seen_ids, id)
        push!(nodes, GraphNode(
            id, "claim", string(row.normalized_claim), string(row.original_wording), string(row.epistemic_state),
            ismissing(row.evidence_id) || row.evidence_id === nothing ? nothing : string(row.evidence_id), Dict{String, Any}("original_wording" => string(row.original_wording))
        ))
    end

    # Methods
    method_rows = Database.query(db, "SELECT id, name, description, evidence_id FROM methods WHERE workspace_id = ? LIMIT ?;", (workspace_id, limit))
    for row in method_rows
        id = string(row.id)
        push!(seen_ids, id)
        push!(nodes, GraphNode(
            id, "method", string(row.name), string(row.description), "source_grounded",
            ismissing(row.evidence_id) || row.evidence_id === nothing ? nothing : string(row.evidence_id), Dict{String, Any}()
        ))
    end

    # Studies
    study_rows = Database.query(db, "SELECT id, title, methodology, findings, evidence_id FROM studies WHERE workspace_id = ? LIMIT ?;", (workspace_id, limit))
    for row in study_rows
        id = string(row.id)
        push!(seen_ids, id)
        push!(nodes, GraphNode(
            id, "study", string(row.title), string(row.findings), "source_grounded",
            ismissing(row.evidence_id) || row.evidence_id === nothing ? nothing : string(row.evidence_id), Dict{String, Any}("methodology" => string(row.methodology))
        ))
    end

    # Sources as nodes
    source_rows = Database.query(db, "SELECT id, title, format, checksum FROM sources WHERE workspace_id = ? LIMIT ?;", (workspace_id, limit))
    for row in source_rows
        id = string(row.id)
        push!(seen_ids, id)
        push!(nodes, GraphNode(
            id, "source", string(row.title), string(row.format), "source_grounded",
            nothing, Dict{String, Any}("checksum" => string(row.checksum))
        ))
    end

    # Edges / Relations
    rel_rows = Database.query(db, """
        SELECT id, source_node_id, source_node_type, target_node_id, target_node_type, relation_type, epistemic_state, provenance_id
        FROM relations
        WHERE workspace_id = ?
        LIMIT ?;
    """, (workspace_id, limit * 2))
    for row in rel_rows
        push!(edges, GraphEdge(
            string(row.id),
            string(row.source_node_id),
            string(row.source_node_type),
            string(row.target_node_id),
            string(row.target_node_type),
            string(row.relation_type),
            string(row.epistemic_state),
            ismissing(row.provenance_id) || row.provenance_id === nothing ? nothing : string(row.provenance_id)
        ))
    end

    return GraphData(nodes, edges)
end

function get_neighborhood(db::SQLite.DB, workspace_id::String, node_id::String; depth::Int=1)
    query_str = """
        SELECT id, source_node_id, source_node_type, target_node_id, target_node_type, relation_type, epistemic_state, provenance_id
        FROM relations
        WHERE workspace_id = ? AND (source_node_id = ? OR target_node_id = ?);
    """
    rows = Database.query(db, query_str, (workspace_id, node_id, node_id))
    edges = GraphEdge[]
    neighbor_ids = Set{String}([node_id])
    
    for row in rows
        src = string(row.source_node_id)
        tgt = string(row.target_node_id)
        push!(neighbor_ids, src)
        push!(neighbor_ids, tgt)
        push!(edges, GraphEdge(
            string(row.id),
            src,
            string(row.source_node_type),
            tgt,
            string(row.target_node_type),
            string(row.relation_type),
            string(row.epistemic_state),
            ismissing(row.provenance_id) || row.provenance_id === nothing ? nothing : string(row.provenance_id)
        ))
    end

    full_g = get_full_graph(db, workspace_id; limit=1000)
    filtered_nodes = filter(n -> n.id in neighbor_ids, full_g.nodes)

    return GraphData(filtered_nodes, edges)
end

end # module GraphQueries
