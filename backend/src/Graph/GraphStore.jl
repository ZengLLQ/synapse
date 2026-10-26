module GraphStore

using UUIDs, Dates, SQLite, DBInterface, JSON3
using ..Entities, ..Relations, ..Epistemic, ..Database, ..AuditService

function add_concept!(db::SQLite.DB, workspace_id::String, name::String, description::String, epistemic_state::String, evidence_id::Union{String, Nothing}; actor::String="system", correlation_id::String=string(uuid4()))
    Epistemic.validate_epistemic_state(epistemic_state)
    id = string(uuid4())
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")

    concept = Entities.Concept(id, workspace_id, name, description, epistemic_state, evidence_id, now_iso, now_iso)
    
    Database.with_transaction(db) do
        Database.execute(db, """
            INSERT INTO concepts (id, workspace_id, name, description, epistemic_state, evidence_id, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """, (id, workspace_id, name, description, epistemic_state, evidence_id, now_iso, now_iso))

        AuditService.record_audit_event!(
            db, workspace_id, actor, id, "concept", "create",
            nothing, JSON3.write(concept), "Created concept: $name"; correlation_id=correlation_id
        )
    end
    return concept
end

function add_claim!(db::SQLite.DB, workspace_id::String, original_wording::String, normalized_claim::String, epistemic_state::String, evidence_id::Union{String, Nothing}; actor::String="system", correlation_id::String=string(uuid4()))
    Epistemic.validate_epistemic_state(epistemic_state)
    id = string(uuid4())
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")

    claim = Entities.Claim(id, workspace_id, original_wording, normalized_claim, epistemic_state, evidence_id, now_iso, now_iso)

    Database.with_transaction(db) do
        Database.execute(db, """
            INSERT INTO claims (id, workspace_id, original_wording, normalized_claim, epistemic_state, evidence_id, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """, (id, workspace_id, original_wording, normalized_claim, epistemic_state, evidence_id, now_iso, now_iso))

        AuditService.record_audit_event!(
            db, workspace_id, actor, id, "claim", "create",
            nothing, JSON3.write(claim), "Created claim: $normalized_claim"; correlation_id=correlation_id
        )
    end
    return claim
end

function add_method!(db::SQLite.DB, workspace_id::String, name::String, description::String, evidence_id::Union{String, Nothing}; actor::String="system", correlation_id::String=string(uuid4()))
    id = string(uuid4())
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    method = Entities.Method(id, workspace_id, name, description, evidence_id, now_iso)

    Database.with_transaction(db) do
        Database.execute(db, """
            INSERT INTO methods (id, workspace_id, name, description, evidence_id, created_at)
            VALUES (?, ?, ?, ?, ?, ?);
        """, (id, workspace_id, name, description, evidence_id, now_iso))

        AuditService.record_audit_event!(
            db, workspace_id, actor, id, "method", "create",
            nothing, JSON3.write(method), "Created method: $name"; correlation_id=correlation_id
        )
    end
    return method
end

function add_study!(db::SQLite.DB, workspace_id::String, title::String, methodology::String, findings::String, evidence_id::Union{String, Nothing}; actor::String="system", correlation_id::String=string(uuid4()))
    id = string(uuid4())
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    study = Entities.Study(id, workspace_id, title, methodology, findings, evidence_id, now_iso)

    Database.with_transaction(db) do
        Database.execute(db, """
            INSERT INTO studies (id, workspace_id, title, methodology, findings, evidence_id, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?);
        """, (id, workspace_id, title, methodology, findings, evidence_id, now_iso))

        AuditService.record_audit_event!(
            db, workspace_id, actor, id, "study", "create",
            nothing, JSON3.write(study), "Created study: $title"; correlation_id=correlation_id
        )
    end
    return study
end

function add_relation!(db::SQLite.DB, workspace_id::String, src_id::String, src_type::String, tgt_id::String, tgt_type::String, rel_type::String, epistemic_state::String, provenance_id::Union{String, Nothing}; actor::String="system", correlation_id::String=string(uuid4()))
    id = string(uuid4())
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    
    relation = Relations.Relation(id, workspace_id, src_id, src_type, tgt_id, tgt_type, rel_type, epistemic_state, provenance_id, now_iso)

    Database.with_transaction(db) do
        Database.execute(db, """
            INSERT INTO relations (id, workspace_id, source_node_id, source_node_type, target_node_id, target_node_type, relation_type, epistemic_state, provenance_id, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """, (id, workspace_id, src_id, src_type, tgt_id, tgt_type, rel_type, epistemic_state, provenance_id, now_iso))

        AuditService.record_audit_event!(
            db, workspace_id, actor, id, "relation", "create",
            nothing, JSON3.write(relation), "Created relation: $src_type ($src_id) -$rel_type-> $tgt_type ($tgt_id)"; correlation_id=correlation_id
        )

        # If relation is CONTRADICTS and both endpoints are claims, update both claims to CONFLICTED state
        if rel_type == Relations.CONTRADICTS
            if src_type == "claim"
                Database.execute(db, "UPDATE claims SET epistemic_state = ? WHERE id = ?;", (Epistemic.CONFLICTED, src_id))
            end
            if tgt_type == "claim"
                Database.execute(db, "UPDATE claims SET epistemic_state = ? WHERE id = ?;", (Epistemic.CONFLICTED, tgt_id))
            end
        end
    end
    return relation
end

end # module GraphStore
