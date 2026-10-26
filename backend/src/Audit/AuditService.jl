module AuditService

using UUIDs, Dates, SQLite, DBInterface, JSON3
using ..Database

struct AuditEvent
    id::String
    workspace_id::String
    correlation_id::String
    actor::String
    target_id::String
    target_type::String
    event_type::String
    before_state::Union{String, Nothing}
    after_state::Union{String, Nothing}
    reason::String
    created_at::String
end

function record_audit_event!(db::SQLite.DB, workspace_id::String, actor::String, target_id::String, target_type::String, event_type::String, before_state::Union{String, Nothing}, after_state::Union{String, Nothing}, reason::String; correlation_id::String=string(uuid4()))
    evt_id = string(uuid4())
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")

    Database.execute(db, """
        INSERT INTO audit_events (id, workspace_id, correlation_id, actor, target_id, target_type, event_type, before_state, after_state, reason, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """, (evt_id, workspace_id, correlation_id, actor, target_id, target_type, event_type, before_state, after_state, reason, now_iso))
    return AuditEvent(evt_id, workspace_id, correlation_id, actor, target_id, target_type, event_type, before_state, after_state, reason, now_iso)
end

function get_audit_events(db::SQLite.DB, workspace_id::String; limit::Int=50, offset::Int=0)
    query = """
        SELECT id, workspace_id, correlation_id, actor, target_id, target_type, event_type, before_state, after_state, reason, created_at
        FROM audit_events
        WHERE workspace_id = ?
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?;
    """
    rows = Database.query(db, query, (workspace_id, limit, offset))
    events = AuditEvent[]
    for row in rows
        push!(events, AuditEvent(
            string(row.id),
            string(row.workspace_id),
            string(row.correlation_id),
            string(row.actor),
            string(row.target_id),
            string(row.target_type),
            string(row.event_type),
            ismissing(row.before_state) || row.before_state === nothing ? nothing : string(row.before_state),
            ismissing(row.after_state) || row.after_state === nothing ? nothing : string(row.after_state),
            string(row.reason),
            string(row.created_at)
        ))
    end
    return events
end

function get_audit_event_by_id(db::SQLite.DB, event_id::String)
    rows = Database.query(db, "SELECT * FROM audit_events WHERE id = ? LIMIT 1;", (event_id,))
    for row in rows
        return AuditEvent(
            string(row.id),
            string(row.workspace_id),
            string(row.correlation_id),
            string(row.actor),
            string(row.target_id),
            string(row.target_type),
            string(row.event_type),
            ismissing(row.before_state) || row.before_state === nothing ? nothing : string(row.before_state),
            ismissing(row.after_state) || row.after_state === nothing ? nothing : string(row.after_state),
            string(row.reason),
            string(row.created_at)
        )
    end
    return nothing
end

function undo_mutation!(db::SQLite.DB, workspace_id::String, audit_event_id::String; actor::String="user")
    target_event = get_audit_event_by_id(db, audit_event_id)
    target_event !== nothing || throw(ArgumentError("Audit event not found: $audit_event_id"))
    target_event.workspace_id == workspace_id || throw(ArgumentError("Workspace mismatch"))

    target_type = target_event.target_type
    target_id = target_event.target_id
    event_type = target_event.event_type

    Database.with_transaction(db) do
        if event_type == "create"
            table_name = if target_type == "concept"
                "concepts"
            elseif target_type == "claim"
                "claims"
            elseif target_type == "relation"
                "relations"
            elseif target_type == "method"
                "methods"
            elseif target_type == "study"
                "studies"
            elseif target_type == "synthesis"
                "syntheses"
            else
                throw(ArgumentError("Unsupported undo target type: $target_type"))
            end

            Database.execute(db, "DELETE FROM $table_name WHERE id = ?;", (target_id,))
            record_audit_event!(db, workspace_id, actor, target_id, target_type, "undo", target_event.after_state, nothing, "Reversed creation of $(target_type) ($target_id) from event $audit_event_id")
        elseif event_type == "update" && target_event.before_state !== nothing
            data = JSON3.read(target_event.before_state)
            if haskey(data, :epistemic_state)
                tbl = target_type == "claim" ? "claims" : (target_type == "concept" ? "concepts" : "relations")
                Database.execute(db, "UPDATE $tbl SET epistemic_state = ? WHERE id = ?;", (string(data[:epistemic_state]), target_id))
            end
            record_audit_event!(db, workspace_id, actor, target_id, target_type, "undo", target_event.after_state, target_event.before_state, "Reversed update of $(target_type) ($target_id) from event $audit_event_id")
        else
            throw(ArgumentError("Cannot automatically undo event type: $event_type"))
        end
    end
    return true
end

end # module AuditService
