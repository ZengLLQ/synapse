module Database

using SQLite, DBInterface, Dates, UUIDs
using ..Schema

function query(db::SQLite.DB, sql::AbstractString, params=())
    if isempty(params)
        return SQLite.Tables.rowtable(DBInterface.execute(db, sql))
    else
        return SQLite.Tables.rowtable(DBInterface.execute(db, sql, params))
    end
end

function execute(db::SQLite.DB, sql::AbstractString, params=())
    q = isempty(params) ? DBInterface.execute(db, sql) : DBInterface.execute(db, sql, params)
    for _ in q end
    return nothing
end

function open_database(db_path::String)
    mkpath(dirname(db_path))
    db = SQLite.DB(db_path)
    
    # Enable WAL mode, foreign keys, synchronous normal, and busy timeout
    execute(db, "PRAGMA journal_mode = WAL;")
    execute(db, "PRAGMA synchronous = NORMAL;")
    execute(db, "PRAGMA foreign_keys = ON;")
    execute(db, "PRAGMA busy_timeout = 5000;")
    
    migrate!(db)
    return db
end

function migrate!(db::SQLite.DB)
    # Check if schema_version exists
    tables = query(db, "SELECT name FROM sqlite_master WHERE type='table' AND name='schema_version';")
    current_v = 0
    if !isempty(tables)
        v_rows = query(db, "SELECT MAX(version) AS max_v FROM schema_version;")
        if !isempty(v_rows)
            v_row = first(v_rows)
            if !ismissing(v_row.max_v) && v_row.max_v !== nothing
                current_v = Int(v_row.max_v)
            end
        end
    end

    if current_v < Schema.CURRENT_SCHEMA_VERSION
        for ddl in Schema.DDL_STATEMENTS
            execute(db, ddl)
        end
        now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
        execute(db, "INSERT INTO schema_version (version, applied_at) VALUES ($(Schema.CURRENT_SCHEMA_VERSION), '$now_iso');")
    end
end

function with_transaction(f::Function, db::SQLite.DB)
    sp_id = "syn_tx_" * replace(string(uuid4()), "-" => "_")
    execute(db, "SAVEPOINT $sp_id;")
    try
        result = f()
        execute(db, "RELEASE $sp_id;")
        return result
    catch err
        try
            execute(db, "ROLLBACK TO $sp_id;")
            execute(db, "RELEASE $sp_id;")
        catch
        end
        rethrow(err)
    end
end

end # module Database
