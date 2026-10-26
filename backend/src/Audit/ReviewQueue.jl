module ReviewQueue

using UUIDs, Dates, SQLite, DBInterface, JSON3
using ..Database, ..AuditService, ..Epistemic

struct ReviewItem
    id::String
    workspace_id::String
    entity_type::String
    entity_id::String
    rationale::String
    confidence::Float64
    status::String
    created_at::String
    reviewed_at::Union{String, Nothing}
end

function create_review_item!(db::SQLite.DB, workspace_id::String, entity_type::String, entity_id::String, rationale::String, confidence::Float64)
    item_id = string(uuid4())
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")

    Database.execute(db, """
        INSERT INTO review_items (id, workspace_id, entity_type, entity_id, rationale, confidence, status, created_at, reviewed_at)
        VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, NULL);
    """, (item_id, workspace_id, entity_type, entity_id, rationale, confidence, now_iso))
    return ReviewItem(item_id, workspace_id, entity_type, entity_id, rationale, confidence, "pending", now_iso, nothing)
end

function list_review_items(db::SQLite.DB, workspace_id::String; status::String="pending")
    query = """
        SELECT id, workspace_id, entity_type, entity_id, rationale, confidence, status, created_at, reviewed_at
        FROM review_items
        WHERE workspace_id = ? AND status = ?
        ORDER BY created_at DESC;
    """
    rows = Database.query(db, query, (workspace_id, status))
    items = ReviewItem[]
    for row in rows
        push!(items, ReviewItem(
            string(row.id),
            string(row.workspace_id),
            string(row.entity_type),
            string(row.entity_id),
            string(row.rationale),
            Float64(row.confidence),
            string(row.status),
            string(row.created_at),
            ismissing(row.reviewed_at) || row.reviewed_at === nothing ? nothing : string(row.reviewed_at)
        ))
    end
    return items
end

function decide_review_item!(db::SQLite.DB, workspace_id::String, review_id::String, action::String, reviewer_notes::String; actor::String="user")
    action in ["accept", "reject"] || throw(ArgumentError("Invalid review action: $action. Must be 'accept' or 'reject'."))
    
    rows = Database.query(db, "SELECT * FROM review_items WHERE id = ? AND workspace_id = ? LIMIT 1;", (review_id, workspace_id))
    isempty(rows) && throw(ArgumentError("Review item not found: $review_id"))
    item = first(rows)

    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    entity_type = string(item.entity_type)
    entity_id = string(item.entity_id)

    Database.with_transaction(db) do
        new_status = action == "accept" ? "accepted" : "rejected"
        Database.execute(db, "UPDATE review_items SET status = ?, reviewed_at = ? WHERE id = ?;", (new_status, now_iso, review_id))

        if action == "accept"
            tbl = if entity_type == "concept"
                "concepts"
            elseif entity_type == "claim"
                "claims"
            elseif entity_type == "relation"
                "relations"
            else
                nothing
            end

            if tbl !== nothing
                Database.execute(db, "UPDATE $tbl SET epistemic_state = ? WHERE id = ?;", (Epistemic.HUMAN_REVIEWED, entity_id))
            end

            AuditService.record_audit_event!(
                db, workspace_id, actor, entity_id, entity_type, "review_accept",
                JSON3.write(Dict("status" => "pending", "epistemic_state" => Epistemic.AI_INFERRED)),
                JSON3.write(Dict("status" => "accepted", "epistemic_state" => Epistemic.HUMAN_REVIEWED, "notes" => reviewer_notes)),
                "Accepted candidate $(entity_type) from review queue"
            )
        else
            AuditService.record_audit_event!(
                db, workspace_id, actor, entity_id, entity_type, "review_reject",
                JSON3.write(Dict("status" => "pending")),
                JSON3.write(Dict("status" => "rejected", "notes" => reviewer_notes)),
                "Rejected candidate $(entity_type) from review queue: $reviewer_notes"
            )
        end
    end
    return true
end

end # module ReviewQueue
