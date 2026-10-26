module WorkspaceManager

using SQLite, DBInterface, Dates, UUIDs
using ..Entities, ..Database

function sanitize_workspace_path(path::String)
    # Prevent path traversal attacks
    resolved = normpath(abspath(path))
    return resolved
end

function create_workspace(global_db::SQLite.DB, name::String, target_path::String)
    clean_path = sanitize_workspace_path(target_path)
    mkpath(clean_path)
    mkpath(joinpath(clean_path, "sources"))
    mkpath(joinpath(clean_path, "indexes"))
    mkpath(joinpath(clean_path, "db"))

    ws_id = string(uuid4())
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    
    # Register in global DB
    Database.with_transaction(global_db) do
        Database.execute(global_db, """
            INSERT INTO workspaces (id, name, path, created_at, updated_at, archived)
            VALUES (?, ?, ?, ?, ?, 0);
        """, (ws_id, name, clean_path, now_iso, now_iso))
    end

    # Also initialize workspace's own SQLite instance
    ws_db_path = joinpath(clean_path, "db", "synapse.db")
    ws_db = Database.open_database(ws_db_path)
    # Ensure workspace record is in the workspace DB too
    Database.with_transaction(ws_db) do
        Database.execute(ws_db, """
            INSERT OR REPLACE INTO workspaces (id, name, path, created_at, updated_at, archived)
            VALUES (?, ?, ?, ?, ?, 0);
        """, (ws_id, name, clean_path, now_iso, now_iso))
    end

    return Entities.Workspace(ws_id, name, clean_path, now_iso, now_iso, false)
end

function get_workspace(db::SQLite.DB, id::String)
    results = Database.query(db, "SELECT id, name, path, created_at, updated_at, archived FROM workspaces WHERE id = ?;", (id,))
    for row in results
        return Entities.Workspace(string(row.id), string(row.name), string(row.path), string(row.created_at), string(row.updated_at), Bool(row.archived))
    end
    return nothing
end

function list_workspaces(db::SQLite.DB; include_archived::Bool = false)
    sql = include_archived ? 
        "SELECT id, name, path, created_at, updated_at, archived FROM workspaces ORDER BY created_at DESC;" :
        "SELECT id, name, path, created_at, updated_at, archived FROM workspaces WHERE archived = 0 ORDER BY created_at DESC;"
    results = Database.query(db, sql)
    workspaces = Entities.Workspace[]
    for row in results
        push!(workspaces, Entities.Workspace(string(row.id), string(row.name), string(row.path), string(row.created_at), string(row.updated_at), Bool(row.archived)))
    end
    return workspaces
end

function rename_workspace(global_db::SQLite.DB, id::String, new_name::String)
    clean_name = strip(new_name)
    !isempty(clean_name) || throw(ArgumentError("Workspace name cannot be empty"))
    
    ws = get_workspace(global_db, id)
    ws !== nothing || throw(ArgumentError("Workspace not found: $id"))
    
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    
    Database.with_transaction(global_db) do
        Database.execute(global_db, "UPDATE workspaces SET name = ?, updated_at = ? WHERE id = ?;", (clean_name, now_iso, id))
    end

    # Also update workspace's internal DB if it exists
    ws_db_path = joinpath(ws.path, "db", "synapse.db")
    if isfile(ws_db_path)
        try
            ws_db = Database.open_database(ws_db_path)
            Database.with_transaction(ws_db) do
                Database.execute(ws_db, "UPDATE workspaces SET name = ?, updated_at = ? WHERE id = ?;", (clean_name, now_iso, id))
            end
            DBInterface.close!(ws_db)
        catch
        end
    end

    return Entities.Workspace(ws.id, clean_name, ws.path, ws.created_at, now_iso, ws.archived)
end

function archive_workspace(global_db::SQLite.DB, id::String)
    ws = get_workspace(global_db, id)
    ws !== nothing || throw(ArgumentError("Workspace not found: $id"))
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    
    Database.with_transaction(global_db) do
        Database.execute(global_db, "UPDATE workspaces SET archived = 1, updated_at = ? WHERE id = ?;", (now_iso, id))
    end

    ws_db_path = joinpath(ws.path, "db", "synapse.db")
    if isfile(ws_db_path)
        try
            ws_db = Database.open_database(ws_db_path)
            Database.with_transaction(ws_db) do
                Database.execute(ws_db, "UPDATE workspaces SET archived = 1, updated_at = ? WHERE id = ?;", (now_iso, id))
            end
            DBInterface.close!(ws_db)
        catch
        end
    end

    return true
end

end # module WorkspaceManager
