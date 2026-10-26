module WorkspaceExport

using SQLite, DBInterface, JSON3, Dates
using ..Database

function export_workspace_data(db::SQLite.DB, workspace_id::String)
    data = Dict{String, Any}()
    data["version"] = "1.0.0"
    data["exported_at"] = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    data["workspace_id"] = workspace_id

    tables = ["workspaces", "sources", "source_versions", "evidence", "concepts", "claims", "methods", "studies", "syntheses", "relations", "audit_events"]
    
    for tbl in tables
        query = tbl == "workspaces" ? 
            "SELECT * FROM workspaces WHERE id = ?;" :
            "SELECT * FROM $tbl WHERE workspace_id = ?;"
        if tbl == "source_versions"
            query = "SELECT sv.* FROM source_versions sv JOIN sources s ON sv.source_id = s.id WHERE s.workspace_id = ?;"
        elseif tbl == "evidence"
            query = "SELECT e.* FROM evidence e JOIN source_versions sv ON e.source_version_id = sv.id JOIN sources s ON sv.source_id = s.id WHERE s.workspace_id = ?;"
        end

        rows_data = Dict{String, Any}[]
        try
            rows = Database.query(db, query, (workspace_id,))
            for row in rows
                row_dict = Dict{String, Any}()
                for col in propertynames(row)
                    val = getproperty(row, col)
                    row_dict[string(col)] = ismissing(val) ? nothing : val
                end
                push!(rows_data, row_dict)
            end
        catch err
            # Table might be empty or query variation
        end
        data[tbl] = rows_data
    end

    return data
end

function export_workspace_to_json(db::SQLite.DB, workspace_id::String, target_file::String)
    data = export_workspace_data(db, workspace_id)
    write(target_file, JSON3.write(data))
    return target_file
end

end # module WorkspaceExport
