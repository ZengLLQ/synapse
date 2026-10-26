module CloudConsentGuard

using UUIDs, Dates, SQLite, DBInterface
using ..Database, ..AuditService

struct ConsentRequiredException <: Exception
    provider::String
    purpose::String
    scope::String
    message::String

    function ConsentRequiredException(provider::String, purpose::String, scope::String)
        new(provider, purpose, scope, "Cloud transmission to '$provider' for '$purpose' under scope '$scope' was blocked. Explicit, informed consent is required.")
    end
end

Base.showerror(io::IO, e::ConsentRequiredException) = print(io, "ConsentRequiredException: ", e.message)

function has_valid_consent(db::SQLite.DB, workspace_id::String, provider::String, purpose::String, scope::String)
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    query = """
        SELECT id FROM consent_records
        WHERE workspace_id = ? AND provider = ? AND purpose = ? AND scope = ? AND revoked = 0 AND valid_until > ?
        LIMIT 1;
    """
    rows = Database.query(db, query, (workspace_id, provider, purpose, scope, now_iso))
    return !isempty(rows)
end

function assert_cloud_consent!(db::SQLite.DB, workspace_id::String, provider::String, purpose::String, scope::String)
    if !has_valid_consent(db, workspace_id, provider, purpose, scope)
        throw(ConsentRequiredException(provider, purpose, scope))
    end
    return true
end

function grant_consent!(db::SQLite.DB, workspace_id::String, provider::String, purpose::String, scope::String, payload_preview::String; duration_hours::Int=24, actor::String="user")
    consent_id = string(uuid4())
    now = Dates.now(Dates.UTC)
    now_iso = Dates.format(now, dateformat"yyyy-mm-ddTHH:MM:SSZ")
    valid_until_iso = Dates.format(now + Dates.Hour(duration_hours), dateformat"yyyy-mm-ddTHH:MM:SSZ")

    Database.with_transaction(db) do
        Database.execute(db, """
            INSERT INTO consent_records (id, workspace_id, provider, purpose, scope, payload_preview, granted_at, valid_until, revoked)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0);
        """, (consent_id, workspace_id, provider, purpose, scope, payload_preview, now_iso, valid_until_iso))

        AuditService.record_audit_event!(
            db, workspace_id, actor, consent_id, "consent_record", "create",
            nothing, "{\"provider\":\"$provider\",\"purpose\":\"$purpose\",\"scope\":\"$scope\",\"valid_until\":\"$valid_until_iso\"}",
            "Granted cloud consent for $provider ($purpose)"; correlation_id=consent_id
        )
    end
    return consent_id
end

function revoke_consent!(db::SQLite.DB, workspace_id::String, consent_id::String; actor::String="user")
    Database.with_transaction(db) do
        Database.execute(db, "UPDATE consent_records SET revoked = 1 WHERE id = ? AND workspace_id = ?;", (consent_id, workspace_id))

        AuditService.record_audit_event!(
            db, workspace_id, actor, consent_id, "consent_record", "update",
            "{\"revoked\":0}", "{\"revoked\":1}", "Revoked cloud consent grant $consent_id"
        )
    end
    return true
end

function list_consent_records(db::SQLite.DB, workspace_id::String)
    query = """
        SELECT id, workspace_id, provider, purpose, scope, payload_preview, granted_at, valid_until, revoked
        FROM consent_records
        WHERE workspace_id = ?
        ORDER BY granted_at DESC;
    """
    rows = Database.query(db, query, (workspace_id,))
    records = Dict{String, Any}[]
    for row in rows
        push!(records, Dict{String, Any}(
            "id" => string(row.id),
            "provider" => string(row.provider),
            "purpose" => string(row.purpose),
            "scope" => string(row.scope),
            "payload_preview" => string(row.payload_preview),
            "granted_at" => string(row.granted_at),
            "valid_until" => string(row.valid_until),
            "revoked" => Bool(row.revoked)
        ))
    end
    return records
end

end # module CloudConsentGuard
