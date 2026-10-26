# backend/test/test_milestone_lifecycle.jl
# Full 11-step End-to-End Milestone Verification (Prompt Section 18)

using Test, Sockets, HTTP, JSON3, SQLite, DBInterface, Dates

using Synapse
using Synapse.Config
using Synapse.Database
using Synapse.WorkspaceManager
using Synapse.SourceService
using Synapse.GraphStore
using Synapse.GraphQueries
using Synapse.FTS5Search
using Synapse.Assistant
using Synapse.CitationValidator
using Synapse.AuditService
using Synapse.ReviewQueue
using Synapse.Server
using Synapse.CloudConsentGuard
using Synapse.JobOrchestrator
using Synapse.WorkspaceExport

@testset "Section 18 End-to-End Milestone Verification" begin
    # Setup temporary directory for isolation
    test_dir = mktempdir()
    global_db_path = joinpath(test_dir, "global_synapse.db")
    port = 8789
    token = "milestone_test_secret_token_2026"
    
    cfg = Config.AppConfig(
        base_dir=test_dir,
        port=port,
        session_token=token,
        log_level="DEBUG"
    )

    println("=== Starting Step 1: Engine Initialization ===")
    # 1. Engine initialization: Start engine, init global DB, verify WAL mode and loopback server
    global_db = Database.open_database(global_db_path)
    # Verify WAL mode
    wal_check = Database.query(global_db, "PRAGMA journal_mode;")
    @test lowercase(string(first(wal_check)[1])) == "wal"

    server = Server.start_server(cfg; global_db=global_db)
    sleep(0.5)

    # Ping health endpoint
    health_resp = HTTP.get("http://127.0.0.1:$port/api/v1/health")
    @test health_resp.status == 200
    health_json = JSON3.read(String(health_resp.body))
    @test health_json.data.status == "ok"
    @test health_json.data.database == "SQLite 3 WAL"
    println("✓ Step 1 Passed: Engine online, WAL active, loopback HTTP responding.")

    println("=== Starting Step 2: Create Workspace ===")
    # 2. Create workspace: Create new workspace, verify isolated directory and schema
    ws_name = "Neuro_Epistemic_Workspace"
    ws_custom_path = joinpath(test_dir, "workspaces", ws_name)
    create_payload = JSON3.write(Dict("name" => ws_name, "path" => ws_custom_path))
    
    create_resp = HTTP.post(
        "http://127.0.0.1:$port/api/v1/workspaces",
        ["Content-Type" => "application/json", "X-Synapse-Token" => token],
        create_payload
    )
    @test create_resp.status == 201
    ws_json = JSON3.read(String(create_resp.body))
    ws_id = ws_json.data.id
    @test !isempty(ws_id)
    @test isfile(joinpath(ws_custom_path, "db", "synapse.db"))
    println("✓ Step 2 Passed: Workspace created at $ws_custom_path with isolated SQLite db.")

    println("=== Starting Step 3 & 4: Import Document & Extract & Index Content ===")
    # 3 & 4. Import document: Create markdown document and import via API
    doc_path = joinpath(test_dir, "transformer_foundation.md")
    write(doc_path, """
# Attention and the Transformer Architecture

We propose the Transformer, an architecture based solely on attention mechanisms, dispensing with recurrence entirely.
The Transformer allows for significantly more parallelization and can reach a new state of the art in translation quality after being trained for as little as twelve hours on eight P100 GPUs.

## Experiments and Results
On the WMT 2014 English-to-German translation task, the big transformer model achieves 28.4 BLEU.
Multi-Head Attention projects queries, keys, and values h times with different, learned linear projections.
""")

    import_payload = JSON3.write(Dict("file_path" => doc_path, "title" => "Attention Paper"))
    import_resp = HTTP.post(
        "http://127.0.0.1:$port/api/v1/workspaces/$ws_id/sources/import",
        ["Content-Type" => "application/json", "X-Synapse-Token" => token],
        import_payload
    )
    @test import_resp.status == 200
    import_json = JSON3.read(String(import_resp.body))
    @test import_json.data.is_duplicate == false
    src_id = import_json.data.source.id
    @test !isempty(src_id)
    @test import_json.data.details.chunks_count >= 1
    println("✓ Steps 3 & 4 Passed: Document imported and indexed with $(import_json.data.details.chunks_count) chunks.")

    println("=== Starting Step 5: Grounded Evidence Record & Extraction ===")
    # 5. Grounded evidence record + candidate claim/concept
    ws_db = Database.open_database(joinpath(ws_custom_path, "db", "synapse.db"))
    ev_records = Database.query(ws_db, "SELECT * FROM evidence")
    @test length(ev_records) > 0
    first_ev = first(ev_records)
    @test first_ev.start_line !== missing
    @test first_ev.end_line !== missing
    @test !isempty(first_ev.excerpt)
    DBInterface.close!(ws_db)
    
    # Verify review queue contains staged candidate extractions
    review_resp = HTTP.get(
        "http://127.0.0.1:$port/api/v1/workspaces/$ws_id/review",
        ["X-Synapse-Token" => token]
    )
    @test review_resp.status == 200
    review_json = JSON3.read(String(review_resp.body))
    @test length(review_json.data) > 0
    println("✓ Step 5 Passed: Grounded evidence records verified with exact lines $(first_ev.start_line)-$(first_ev.end_line). Staged review items: $(length(review_json.data)).")

    println("=== Starting Step 6: Graph Neighborhood Query ===")
    # 6. Graph neighborhood query: Query graph for extracted nodes and edges
    graph_resp = HTTP.get(
        "http://127.0.0.1:$port/api/v1/workspaces/$ws_id/graph",
        ["X-Synapse-Token" => token]
    )
    @test graph_resp.status == 200
    graph_json = JSON3.read(String(graph_resp.body))
    @test length(graph_json.data.nodes) > 0
    first_node_id = graph_json.data.nodes[1].id

    # Query neighborhood of first node
    nb_resp = HTTP.get(
        "http://127.0.0.1:$port/api/v1/workspaces/$ws_id/graph/neighborhood/$first_node_id",
        ["X-Synapse-Token" => token]
    )
    @test nb_resp.status == 200
    nb_json = JSON3.read(String(nb_resp.body))
    @test length(nb_json.data.nodes) >= 1
    println("✓ Step 6 Passed: Graph store populated with $(length(graph_json.data.nodes)) nodes and $(length(graph_json.data.edges)) edges. Neighborhood query verified.")

    println("=== Starting Step 7: FTS5 Text Search ===")
    # 7. FTS5 text search: Search for exact terms, verify relevance ranking
    search_resp = HTTP.get(
        "http://127.0.0.1:$port/api/v1/workspaces/$ws_id/search?q=Transformer&limit=5",
        ["X-Synapse-Token" => token]
    )
    @test search_resp.status == 200
    search_json = JSON3.read(String(search_resp.body))
    @test length(search_json.data) > 0
    @test occursin("Transformer", search_json.data[1].content)
    println("✓ Step 7 Passed: FTS5 query returned $(length(search_json.data)) matching chunks.")

    println("=== Starting Step 8: Cross-Source QA Question ===")
    # 8. Cross-source QA question: Synthesize answer with citations and epistemic badge
    ask_payload = JSON3.write(Dict("question" => "What translation score does the Transformer achieve on WMT 2014?", "limit" => 5))
    ask_resp = HTTP.post(
        "http://127.0.0.1:$port/api/v1/workspaces/$ws_id/research/ask",
        ["Content-Type" => "application/json", "X-Synapse-Token" => token],
        ask_payload
    )
    @test ask_resp.status == 200
    ask_json = JSON3.read(String(ask_resp.body))
    @test !isempty(ask_json.data.answer)
    @test ask_json.data.epistemic_state in ["source_grounded", "ai_inferred"]
    @test length(ask_json.data.citations) > 0
    println("✓ Step 8 Passed: Assistant answered question with epistemic state '$(ask_json.data.epistemic_state)' and $(length(ask_json.data.citations)) citations.")

    println("=== Starting Step 9: Citation Locator Resolution ===")
    # 9. Citation locator resolution: Verify every citation tag resolves to valid source and locator
    for cite in ask_json.data.citations
        @test cite.is_valid == true
        @test !isempty(cite.source_id)
        @test !isempty(cite.evidence_id)
        @test !isempty(cite.locator)
    end
    println("✓ Step 9 Passed: 100% of citation locators resolved successfully.")

    println("=== Starting Step 10: Provenance & Audit Event Inspection ===")
    # 10. Provenance & audit event inspection: Verify all actions emitted immutable AuditEvents
    audit_resp = HTTP.get(
        "http://127.0.0.1:$port/api/v1/workspaces/$ws_id/audit",
        ["X-Synapse-Token" => token]
    )
    @test audit_resp.status == 200
    audit_json = JSON3.read(String(audit_resp.body))
    @test length(audit_json.data) >= 1
    # Check that events have actor, timestamp, target, and event_type
    for event in audit_json.data
        @test !isempty(event.actor)
        @test !isempty(event.event_type)
        @test !isempty(event.created_at)
    end
    println("✓ Step 10 Passed: Audit log contains $(length(audit_json.data)) immutable audit events.")

    println("=== Starting Step 10b: Document Content and Evidence Retrieval Endpoints ===")
    content_resp = HTTP.get(
        "http://127.0.0.1:$port/api/v1/workspaces/$ws_id/sources/$src_id/content",
        ["X-Synapse-Token" => token]
    )
    @test content_resp.status == 200
    content_json = JSON3.read(String(content_resp.body))
    @test occursin("Attention and the Transformer Architecture", content_json.data.content)
    @test content_json.data.source.id == src_id

    ev_list_resp = HTTP.get(
        "http://127.0.0.1:$port/api/v1/workspaces/$ws_id/sources/$src_id/evidence",
        ["X-Synapse-Token" => token]
    )
    @test ev_list_resp.status == 200
    ev_list_json = JSON3.read(String(ev_list_resp.body))
    @test length(ev_list_json.data) >= 1
    sample_ev_id = ev_list_json.data[1].id

    single_ev_resp = HTTP.get(
        "http://127.0.0.1:$port/api/v1/workspaces/$ws_id/evidence/$sample_ev_id",
        ["X-Synapse-Token" => token]
    )
    @test single_ev_resp.status == 200
    single_ev_json = JSON3.read(String(single_ev_resp.body))
    @test single_ev_json.data.id == sample_ev_id
    @test single_ev_json.data.start_line >= 1
    println("✓ Step 10b Passed: Real source content and granular evidence endpoints verified.")

    println("=== Starting Step 10c: Flexible Neighborhood Query with Query Param ===")
    nb_param_resp = HTTP.get(
        "http://127.0.0.1:$port/api/v1/workspaces/$ws_id/graph/neighborhood?node_id=$first_node_id",
        ["X-Synapse-Token" => token]
    )
    @test nb_param_resp.status == 200
    nb_param_json = JSON3.read(String(nb_param_resp.body))
    @test length(nb_param_json.data.nodes) >= 1
    println("✓ Step 10c Passed: Neighborhood query via ?node_id= parameter verified.")

    println("=== Starting Step 10d: Durable Background Job Orchestration & Retries ===")
    ws_db = Database.open_database(joinpath(ws_custom_path, "db", "synapse.db"))
    test_job = JobOrchestrator.create_job(ws_db, ws_id, "embedding_indexing", "doc_fp_101")
    JobOrchestrator.fail_job(ws_db, test_job.id, "Simulated network timeout during remote sync")
    DBInterface.close!(ws_db)

    jobs_resp = HTTP.get(
        "http://127.0.0.1:$port/api/v1/workspaces/$ws_id/jobs",
        ["X-Synapse-Token" => token]
    )
    @test jobs_resp.status == 200
    jobs_json = JSON3.read(String(jobs_resp.body))
    @test length(jobs_json.data) >= 1
    target_job = findfirst(j -> j.id == test_job.id, jobs_json.data)
    @test target_job !== nothing
    @test jobs_json.data[target_job].status == "failed"
    @test jobs_json.data[target_job].attempts == 1

    retry_resp = HTTP.post(
        "http://127.0.0.1:$port/api/v1/workspaces/$ws_id/jobs/$(test_job.id)/retry",
        ["Content-Type" => "application/json", "X-Synapse-Token" => token],
        "{}"
    )
    @test retry_resp.status == 200
    retry_json = JSON3.read(String(retry_resp.body))
    @test retry_json.data.status == "queued"
    @test retry_json.data.attempts == 2
    println("✓ Step 10d Passed: Job tracking, listing, and bounded retry via API verified.")

    println("=== Starting Step 10e: Workspace Renaming and Archival API ===")
    new_ws_name = "Neuro_Epistemic_Workspace_Renamed"
    rename_resp = HTTP.post(
        "http://127.0.0.1:$port/api/v1/workspaces/$ws_id/rename",
        ["Content-Type" => "application/json", "X-Synapse-Token" => token],
        JSON3.write(Dict("name" => new_ws_name))
    )
    @test rename_resp.status == 200
    rename_json = JSON3.read(String(rename_resp.body))
    @test rename_json.data.name == new_ws_name

    archive_resp = HTTP.post(
        "http://127.0.0.1:$port/api/v1/workspaces/$ws_id/archive",
        ["Content-Type" => "application/json", "X-Synapse-Token" => token],
        "{}"
    )
    @test archive_resp.status == 200
    archive_json = JSON3.read(String(archive_resp.body))
    @test archive_json.data.archived == true
    println("✓ Step 10e Passed: Workspace rename and archival API verified.")

    println("=== Starting Step 11: State Persistence Across Restarts ===")
    # 11. State persistence across restarts: Shut down server, close DB, re-open from disk, verify data intact
    Server.stop_server!(server)
    sleep(0.5)

    # Re-open databases from disk without deleting files
    reopened_global_db = Database.open_database(global_db_path)
    ws_reopened = WorkspaceManager.get_workspace(reopened_global_db, ws_id)
    @test ws_reopened !== nothing
    @test ws_reopened.name == new_ws_name
    @test ws_reopened.archived == true

    reopened_ws_db = Database.open_database(joinpath(ws_custom_path, "db", "synapse.db"))
    reopened_sources = SourceService.list_sources(reopened_ws_db, ws_id)
    @test length(reopened_sources) == 1
    @test reopened_sources[1].id == src_id

    reopened_graph = GraphQueries.get_full_graph(reopened_ws_db, ws_id)
    @test length(reopened_graph.nodes) == length(graph_json.data.nodes)
    @test length(reopened_graph.edges) == length(graph_json.data.edges)

    reopened_audit = AuditService.get_audit_events(reopened_ws_db, ws_id)
    @test length(reopened_audit) == length(audit_json.data)

    DBInterface.close!(reopened_ws_db)
    DBInterface.close!(reopened_global_db)
    println("✓ Step 11 Passed: Full persistence verified. All sources, nodes, edges, and audit events restored intact.")

    # Cleanup temporary test files
    GC.gc()
    GC.gc()
    sleep(0.3)
    try
        rm(test_dir, recursive=true, force=true)
    catch
    end
    println("=== All 11 Milestone Steps Passed Cleanly! ===")
end
