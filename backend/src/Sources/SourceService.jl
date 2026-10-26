module SourceService

using SHA, Dates, UUIDs, SQLite, DBInterface
using ..Entities, ..Database

function compute_file_checksum(file_path::String)
    bytes = read(file_path)
    return bytes2hex(sha256(bytes))
end

function find_existing_source_by_checksum(db::SQLite.DB, workspace_id::String, checksum::String)
    results = Database.query(db, "SELECT id, workspace_id, title, format, checksum, original_path, managed_path, created_at, updated_at FROM sources WHERE workspace_id = ? AND checksum = ? LIMIT 1;", (workspace_id, checksum))
    for row in results
        return Entities.Source(string(row.id), string(row.workspace_id), string(row.title), string(row.format), string(row.checksum), string(row.original_path), string(row.managed_path), string(row.created_at), string(row.updated_at))
    end
    return nothing
end

function import_source_file(db::SQLite.DB, workspace_id::String, workspace_path::String, original_path::String; title::Union{String, Nothing}=nothing)
    isfile(original_path) || throw(SystemError("File not found: $original_path"))
    
    checksum = compute_file_checksum(original_path)
    existing = find_existing_source_by_checksum(db, workspace_id, checksum)
    if existing !== nothing
        # Deduplication match: file already exists
        return (source = existing, is_duplicate = true, version_id = get_latest_version_id(db, existing.id))
    end

    ext = lowercase(splitext(original_path)[2])
    doc_format = if ext in [".md", ".markdown"]
        "markdown"
    elseif ext == ".txt"
        "plaintext"
    elseif ext == ".pdf"
        "pdf"
    else
        throw(ArgumentError("Unsupported file extension: $ext"))
    end

    resolved_title = title !== nothing ? title : splitext(basename(original_path))[1]
    managed_filename = "$(checksum[1:12])_$(basename(original_path))"
    managed_dir = joinpath(workspace_path, "sources")
    mkpath(managed_dir)
    managed_path = joinpath(managed_dir, managed_filename)
    cp(original_path, managed_path; force=true)

    source_id = string(uuid4())
    version_id = string(uuid4())
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")

    total_bytes = filesize(managed_path)

    Database.with_transaction(db) do
        Database.execute(db, """
            INSERT INTO sources (id, workspace_id, title, format, checksum, original_path, managed_path, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """, (source_id, workspace_id, resolved_title, doc_format, checksum, original_path, managed_path, now_iso, now_iso))

        Database.execute(db, """
            INSERT INTO source_versions (id, source_id, version_number, checksum, total_pages, total_lines, total_bytes, created_at)
            VALUES (?, ?, 1, ?, 1, 0, ?, ?);
        """, (version_id, source_id, checksum, total_bytes, now_iso))
    end

    new_source = Entities.Source(source_id, workspace_id, resolved_title, doc_format, checksum, original_path, managed_path, now_iso, now_iso)
    return (source = new_source, is_duplicate = false, version_id = version_id)
end

function get_latest_version_id(db::SQLite.DB, source_id::String)
    results = Database.query(db, "SELECT id FROM source_versions WHERE source_id = ? ORDER BY version_number DESC LIMIT 1;", (source_id,))
    for row in results
        return string(row.id)
    end
    return nothing
end

function list_sources(db::SQLite.DB, workspace_id::String)
    results = Database.query(db, "SELECT id, workspace_id, title, format, checksum, original_path, managed_path, created_at, updated_at FROM sources WHERE workspace_id = ? ORDER BY created_at DESC;", (workspace_id,))
    sources = Entities.Source[]
    for row in results
        push!(sources, Entities.Source(string(row.id), string(row.workspace_id), string(row.title), string(row.format), string(row.checksum), string(row.original_path), string(row.managed_path), string(row.created_at), string(row.updated_at)))
    end
    return sources
end

function get_source(db::SQLite.DB, source_id::String)
    results = Database.query(db, "SELECT id, workspace_id, title, format, checksum, original_path, managed_path, created_at, updated_at FROM sources WHERE id = ? LIMIT 1;", (source_id,))
    for row in results
        return Entities.Source(string(row.id), string(row.workspace_id), string(row.title), string(row.format), string(row.checksum), string(row.original_path), string(row.managed_path), string(row.created_at), string(row.updated_at))
    end
    return nothing
end

end # module SourceService
