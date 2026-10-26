module Server

using HTTP, JSON3, SQLite, DBInterface, Dates, Sockets, URIs
using ..Config: AppConfig
using ..Database
using ..WorkspaceManager, ..SourceService, ..GraphQueries, ..GraphStore
using ..FTS5Search, ..Assistant, ..AuditService, ..ReviewQueue
using ..JobOrchestrator, ..CloudConsentGuard, ..WorkspaceExport
using ..Routes: json_response, error_response, handle_options, execute_ingestion_pipeline

struct SynapseServer
    config::AppConfig
    global_db::SQLite.DB
    workspace_dbs::Dict{String, SQLite.DB}
    server_task::Ref{Union{Task, Nothing}}
    http_server::Ref{Union{HTTP.Server, Nothing}}
end

function is_allowed_origin(origin::AbstractString)
    # Allow Tauri app, localhost, 127.0.0.1
    return startswith(origin, "http://localhost") ||
           startswith(origin, "http://127.0.0.1") ||
           startswith(origin, "tauri://localhost") ||
           startswith(origin, "https://tauri.localhost") ||
           origin == "null"
end

function get_workspace_db(server::SynapseServer, workspace_id::String)
    ws = WorkspaceManager.get_workspace(server.global_db, workspace_id)
    ws !== nothing || throw(ArgumentError("Workspace not found: $workspace_id"))
    db = get!(server.workspace_dbs, workspace_id) do
        db_path = joinpath(ws.path, "db", "synapse.db")
        Database.open_database(db_path)
    end
    return (ws = ws, db = db)
end

function router(server::SynapseServer, req::HTTP.Request)
    if req.method == "OPTIONS"
        return handle_options(req)
    end

    # 1. Origin header verification
    origin = HTTP.header(req, "Origin", "")
    if !isempty(origin) && !is_allowed_origin(origin)
        return error_response("FORBIDDEN_ORIGIN", "Origin '$origin' not permitted on loopback API.", status=403)
    end

    uri = URI(req.target)
    path = uri.path
    path_segments = filter(!isempty, split(path, '/'))

    # Health check is open for monitoring
    if req.method == "GET" && path == "/api/v1/health"
        return json_response(Dict(
            "status" => "ok",
            "version" => "0.1.0",
            "engine" => "Julia 1.13",
            "database" => "SQLite 3 WAL",
            "uptime_utc" => Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
        ))
    end

    # 2. Authentication Token Check
    token = HTTP.header(req, "X-Synapse-Token", "")
    if token != server.config.session_token
        return error_response("UNAUTHORIZED", "Invalid or missing X-Synapse-Token header.", status=401)
    end

    try
        # Workspaces API
        if path == "/api/v1/workspaces"
            if req.method == "GET"
                workspaces = WorkspaceManager.list_workspaces(server.global_db)
                return json_response(workspaces)
            elseif req.method == "POST"
                body = JSON3.read(String(req.body))
                name = string(body[:name])
                custom_path = haskey(body, :path) ? string(body[:path]) : joinpath(server.config.base_dir, "workspaces", name)
                ws = WorkspaceManager.create_workspace(server.global_db, name, custom_path)
                return json_response(ws, status=201)
            end
        end

        # Routes with /api/v1/workspaces/:workspace_id/...
        if length(path_segments) >= 4 && path_segments[1] == "api" && path_segments[2] == "v1" && path_segments[3] == "workspaces"
            ws_id = String(path_segments[4])
            ws_info = get_workspace_db(server, ws_id)
            ws = ws_info.ws
            db = ws_info.db

            subpath = path_segments[5:end]
            
            # Workspace operations: GET, PATCH, rename, archive
            if isempty(subpath)
                if req.method == "GET"
                    return json_response(ws)
                elseif req.method == "PATCH"
                    body = JSON3.read(String(req.body))
                    if haskey(body, :name)
                        new_name = string(body[:name])
                        updated_ws = WorkspaceManager.rename_workspace(server.global_db, ws_id, new_name)
                        return json_response(updated_ws)
                    end
                end
            elseif length(subpath) == 1 && subpath[1] == "rename" && req.method == "POST"
                body = JSON3.read(String(req.body))
                new_name = string(body[:name])
                updated_ws = WorkspaceManager.rename_workspace(server.global_db, ws_id, new_name)
                return json_response(updated_ws)
            elseif length(subpath) == 1 && subpath[1] == "archive" && req.method == "POST"
                WorkspaceManager.archive_workspace(server.global_db, ws_id)
                return json_response(Dict("archived" => true, "workspace_id" => ws_id))
            end

            # Sources: /api/v1/workspaces/:id/sources
            if length(subpath) >= 1 && subpath[1] == "sources"
                if length(subpath) == 1 && req.method == "GET"
                    return json_response(SourceService.list_sources(db, ws_id))
                elseif length(subpath) == 2 && subpath[2] == "import" && req.method == "POST"
                    body = JSON3.read(String(req.body))
                    file_path = string(body[:file_path])
                    title = haskey(body, :title) ? string(body[:title]) : nothing
                    
                    job = JobOrchestrator.create_job(db, ws_id, "document_ingestion", file_path)
                    JobOrchestrator.update_job_progress(db, job.id, "parsing_and_indexing", 0.5)

                    res = execute_ingestion_pipeline(db, ws_id, ws.path, file_path; title=title)
                    
                    JobOrchestrator.complete_job(db, job.id, Dict{String, Any}("source_id" => res.source.id, "is_duplicate" => res.is_duplicate))
                    return json_response(Dict(
                        "job_id" => job.id,
                        "source" => res.source,
                        "is_duplicate" => res.is_duplicate,
                        "details" => res
                    ))
                elseif length(subpath) == 2 && req.method == "GET"
                    src_id = String(subpath[2])
                    src = SourceService.get_source(db, src_id)
                    src !== nothing || return error_response("NOT_FOUND", "Source not found", status=404)
                    return json_response(src)
                elseif length(subpath) == 3 && subpath[3] == "content" && req.method == "GET"
                    src_id = String(subpath[2])
                    src = SourceService.get_source(db, src_id)
                    src !== nothing || return error_response("NOT_FOUND", "Source not found", status=404)
                    content = isfile(src.managed_path) ? read(src.managed_path, String) : ""
                    return json_response(Dict("source" => src, "content" => content))
                elseif length(subpath) == 3 && subpath[3] == "evidence" && req.method == "GET"
                    src_id = String(subpath[2])
                    ev_query = """
                        SELECT e.id, e.source_version_id, e.page_number, e.start_line, e.end_line, e.start_char, e.end_char, e.excerpt, e.created_at
                        FROM evidence e
                        JOIN source_versions sv ON e.source_version_id = sv.id
                        WHERE sv.source_id = ?
                        ORDER BY e.start_line ASC;
                    """
                    ev_rows = Database.query(db, ev_query, (src_id,))
                    ev_list = Dict{String, Any}[]
                    for r in ev_rows
                        push!(ev_list, Dict{String, Any}(
                            "id" => string(r.id),
                            "source_version_id" => string(r.source_version_id),
                            "page_number" => ismissing(r.page_number) || r.page_number === nothing ? nothing : Int(r.page_number),
                            "start_line" => ismissing(r.start_line) || r.start_line === nothing ? nothing : Int(r.start_line),
                            "end_line" => ismissing(r.end_line) || r.end_line === nothing ? nothing : Int(r.end_line),
                            "start_char" => ismissing(r.start_char) || r.start_char === nothing ? nothing : Int(r.start_char),
                            "end_char" => ismissing(r.end_char) || r.end_char === nothing ? nothing : Int(r.end_char),
                            "excerpt" => string(r.excerpt),
                            "created_at" => string(r.created_at)
                        ))
                    end
                    return json_response(ev_list)
                end
            end

            # Direct Evidence: /api/v1/workspaces/:id/evidence/:evidence_id
            if length(subpath) == 2 && subpath[1] == "evidence" && req.method == "GET"
                ev_id = String(subpath[2])
                ev_rows = Database.query(db, "SELECT * FROM evidence WHERE id = ? LIMIT 1;", (ev_id,))
                isempty(ev_rows) && return error_response("NOT_FOUND", "Evidence not found", status=404)
                r = first(ev_rows)
                return json_response(Dict(
                    "id" => string(r.id),
                    "source_version_id" => string(r.source_version_id),
                    "page_number" => ismissing(r.page_number) || r.page_number === nothing ? nothing : Int(r.page_number),
                    "start_line" => ismissing(r.start_line) || r.start_line === nothing ? nothing : Int(r.start_line),
                    "end_line" => ismissing(r.end_line) || r.end_line === nothing ? nothing : Int(r.end_line),
                    "start_char" => ismissing(r.start_char) || r.start_char === nothing ? nothing : Int(r.start_char),
                    "end_char" => ismissing(r.end_char) || r.end_char === nothing ? nothing : Int(r.end_char),
                    "excerpt" => string(r.excerpt),
                    "created_at" => string(r.created_at)
                ))
            end

            # Search: /api/v1/workspaces/:id/search?q=...
            if length(subpath) == 1 && subpath[1] == "search" && req.method == "GET"
                q_params = HTTP.queryparams(uri)
                q_str = get(q_params, "q", "")
                limit_n = parse(Int, get(q_params, "limit", "10"))
                results = FTS5Search.search_fts(db, ws_id, q_str; limit=limit_n)
                return json_response(results)
            end

            # Graph: /api/v1/workspaces/:id/graph
            if length(subpath) >= 1 && subpath[1] == "graph"
                if length(subpath) == 1 && req.method == "GET"
                    return json_response(GraphQueries.get_full_graph(db, ws_id))
                elseif length(subpath) >= 2 && subpath[2] == "neighborhood" && req.method == "GET"
                    q_params = HTTP.queryparams(uri)
                    node_id = length(subpath) >= 3 ? String(subpath[3]) : get(q_params, "node_id", "")
                    !isempty(node_id) || return error_response("BAD_REQUEST", "Missing node_id parameter", status=400)
                    return json_response(GraphQueries.get_neighborhood(db, ws_id, node_id))
                elseif length(subpath) == 2 && subpath[2] == "undo" && req.method == "POST"
                    body = JSON3.read(String(req.body))
                    event_id = string(body[:audit_event_id])
                    AuditService.undo_mutation!(db, ws_id, event_id)
                    return json_response(Dict("undone" => true, "audit_event_id" => event_id))
                end
            end

            # Research: /api/v1/workspaces/:id/research/...
            if length(subpath) >= 2 && subpath[1] == "research"
                if subpath[2] == "ask" && req.method == "POST"
                    body = JSON3.read(String(req.body))
                    question = string(body[:question])
                    limit_n = haskey(body, :limit) ? Int(body[:limit]) : 5
                    ans = Assistant.ask_research_question(db, ws_id, question; limit=limit_n)
                    return json_response(ans)
                elseif subpath[2] in ("save_synthesis", "synthesize") && req.method == "POST"
                    body = JSON3.read(String(req.body))
                    question = string(body[:question])
                    answer = string(body[:answer])
                    limitations = string(body[:limitations])
                    cites = CitationValidator.ResolvedCitation[]
                    if haskey(body, :citations)
                        for c in body[:citations]
                            push!(cites, CitationValidator.ResolvedCitation(
                                string(c[:raw_tag]), string(c[:source_id]), string(c[:evidence_id]),
                                string(c[:source_title]), string(c[:locator]), string(c[:excerpt]),
                                Bool(c[:is_valid]), nothing
                            ))
                        end
                    end
                    saved = Assistant.save_synthesis!(db, ws_id, question, answer, limitations, cites)
                    return json_response(saved, status=201)
                end
            end

            # Review Queue: /api/v1/workspaces/:id/review
            if length(subpath) >= 1 && subpath[1] == "review"
                if length(subpath) == 1 && req.method == "GET"
                    items = ReviewQueue.list_review_items(db, ws_id)
                    return json_response(items)
                elseif length(subpath) == 3 && subpath[3] == "decide" && req.method == "POST"
                    review_id = String(subpath[2])
                    body = JSON3.read(String(req.body))
                    action = string(body[:action])
                    notes = haskey(body, :notes) ? string(body[:notes]) : ""
                    ReviewQueue.decide_review_item!(db, ws_id, review_id, action, notes)
                    return json_response(Dict("decided" => true, "review_id" => review_id, "action" => action))
                end
            end

            # Audit Events: /api/v1/workspaces/:id/audit
            if length(subpath) >= 1 && subpath[1] == "audit"
                if length(subpath) == 1 && req.method == "GET"
                    events = AuditService.get_audit_events(db, ws_id)
                    return json_response(events)
                elseif length(subpath) == 2 && subpath[2] == "undo" && req.method == "POST"
                    body = JSON3.read(String(req.body))
                    event_id = string(body[:audit_event_id])
                    AuditService.undo_mutation!(db, ws_id, event_id)
                    return json_response(Dict("undone" => true, "audit_event_id" => event_id))
                end
            end

            # Jobs: /api/v1/workspaces/:id/jobs
            if length(subpath) >= 1 && subpath[1] == "jobs"
                if length(subpath) == 1 && req.method == "GET"
                    return json_response(JobOrchestrator.list_jobs(db, ws_id))
                elseif length(subpath) >= 2
                    job_id = String(subpath[2])
                    if length(subpath) == 2 && req.method == "GET"
                        j = JobOrchestrator.get_job(db, job_id)
                        j !== nothing || return error_response("NOT_FOUND", "Job not found", status=404)
                        return json_response(j)
                    elseif length(subpath) == 3 && subpath[3] == "cancel" && req.method == "POST"
                        JobOrchestrator.request_job_cancellation(db, job_id)
                        return json_response(Dict("cancelled" => true, "job_id" => job_id))
                    elseif length(subpath) == 3 && subpath[3] == "retry" && req.method == "POST"
                        retried_job = JobOrchestrator.retry_job!(db, job_id)
                        if retried_job.job_type == "document_ingestion" && isfile(retried_job.input_fingerprint)
                            JobOrchestrator.update_job_progress(db, job_id, "retrying_pipeline", 0.5)
                            res = execute_ingestion_pipeline(db, ws_id, ws.path, retried_job.input_fingerprint)
                            JobOrchestrator.complete_job(db, job_id, Dict{String, Any}("source_id" => res.source.id, "is_duplicate" => res.is_duplicate))
                            retried_job = JobOrchestrator.get_job(db, job_id)
                        end
                        return json_response(retried_job)
                    end
                end
            end

            # Cloud Consent: /api/v1/workspaces/:id/consent or /consents
            if length(subpath) >= 1 && (subpath[1] == "consent" || subpath[1] == "consents")
                if length(subpath) == 1 && req.method == "GET"
                    return json_response(CloudConsentGuard.list_consent_records(db, ws_id))
                elseif length(subpath) == 2 && subpath[2] == "grant" && req.method == "POST"
                    body = JSON3.read(String(req.body))
                    provider = string(body[:provider])
                    purpose = string(body[:purpose])
                    scope = string(body[:scope])
                    preview = string(body[:payload_preview])
                    hours = haskey(body, :duration_hours) ? Int(body[:duration_hours]) : 24
                    cid = CloudConsentGuard.grant_consent!(db, ws_id, provider, purpose, scope, preview; duration_hours=hours)
                    return json_response(Dict("consent_id" => cid), status=201)
                elseif length(subpath) == 2 && subpath[2] == "revoke" && req.method == "POST"
                    body = JSON3.read(String(req.body))
                    cid = string(body[:consent_id])
                    CloudConsentGuard.revoke_consent!(db, ws_id, cid)
                    return json_response(Dict("revoked" => true, "consent_id" => cid))
                end
            end

            # Export: /api/v1/workspaces/:id/export
            if length(subpath) == 1 && subpath[1] == "export" && req.method == "GET"
                data = WorkspaceExport.export_workspace_data(db, ws_id)
                return json_response(data)
            end
        end

        return error_response("NOT_FOUND", "Endpoint $(req.method) $path not found.", status=404)
    catch err
        if isa(err, CloudConsentGuard.ConsentRequiredException)
            return error_response("CONSENT_REQUIRED", err.message, status=403, details=Dict("provider" => err.provider, "purpose" => err.purpose, "scope" => err.scope))
        end
        return error_response("INTERNAL_ERROR", sprint(showerror, err), status=500)
    end
end

function start_server(config::AppConfig; global_db::Union{SQLite.DB, Nothing} = nothing)
    if global_db === nothing
        global_db_path = joinpath(config.base_dir, "synapse_global.db")
        global_db = Database.open_database(global_db_path)
    end

    synapse_srv = SynapseServer(config, global_db, Dict{String, SQLite.DB}(), Ref{Union{Task, Nothing}}(nothing), Ref{Union{HTTP.Server, Nothing}}(nothing))

    handler = req -> router(synapse_srv, req)
    host = "127.0.0.1"
    port = config.default_port

    server = HTTP.serve!(handler, host, port)
    synapse_srv.http_server[] = server
    return synapse_srv
end

function stop_server(srv::SynapseServer)
    if srv.http_server[] !== nothing
        close(srv.http_server[])
        srv.http_server[] = nothing
    end
    for (_, ws_db) in srv.workspace_dbs
        try
            DBInterface.close!(ws_db)
        catch
        end
    end
    empty!(srv.workspace_dbs)
    try
        DBInterface.close!(srv.global_db)
    catch
    end
end

const stop_server! = stop_server

end # module Server
