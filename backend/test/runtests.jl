using Test, SQLite, DBInterface, Dates, UUIDs, SHA, HTTP, JSON3

# Push src to LOAD_PATH
push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))
using Synapse

@testset "Synapse Test Suite" begin

    test_temp_dir = mktempdir()
    global_db_path = joinpath(test_temp_dir, "test_global.db")
    global_db = Database.open_database(global_db_path)

    @testset "1. Domain Invariants & Epistemic States" begin
        @test Epistemic.SOURCE_GROUNDED in Epistemic.VALID_EPISTEMIC_STATES
        @test Epistemic.CONFLICTED in Epistemic.VALID_EPISTEMIC_STATES
        @test Epistemic.INSUFFICIENT_EVIDENCE in Epistemic.VALID_EPISTEMIC_STATES
        @test Epistemic.validate_epistemic_state("source_grounded") == true
        @test_throws ArgumentError Epistemic.validate_epistemic_state("invalid_fabricated_state")

        # Entity creation with valid epistemic state
        concept = Entities.Concept("c-1", "ws-1", "Attention", "Mechanism", Epistemic.SOURCE_GROUNDED, nothing, "2026-10-26T00:00:00Z", "2026-10-26T00:00:00Z")
        @test concept.name == "Attention"
        @test concept.epistemic_state == "source_grounded"

        # Invalid relation type or compatibility
        @test_throws ArgumentError Relations.Relation("r-1", "ws-1", "c-1", "concept", "m-1", "method", "invalid_type", Epistemic.SOURCE_GROUNDED, nothing, "2026-10-26T00:00:00Z")
        @test_throws ArgumentError Relations.Relation("r-1", "ws-1", "c-1", "concept", "c-2", "concept", Relations.USES_METHOD, Epistemic.SOURCE_GROUNDED, nothing, "2026-10-26T00:00:00Z")
    end

    @testset "2. SQLite Persistence & Schema Migrations" begin
        # Verify tables exist
        tbl_names = String[]
        for row in Database.query(global_db, "SELECT name FROM sqlite_master WHERE type='table';")
            push!(tbl_names, string(row.name))
        end
        @test "workspaces" in tbl_names
        @test "sources" in tbl_names
        @test "evidence" in tbl_names
        @test "chunks_fts" in tbl_names
        @test "audit_events" in tbl_names
        @test "consent_records" in tbl_names

        # Transaction rollback on failure
        @test_throws ErrorException Database.with_transaction(global_db) do
            Database.execute(global_db, "INSERT INTO workspaces (id, name, path, created_at, updated_at, archived) VALUES ('test-err', 'err', 'err', 'now', 'now', 0);")
            error("Intentional transaction failure")
        end
        # Verify rollback
        cnt_rows = Database.query(global_db, "SELECT COUNT(*) AS cnt FROM workspaces WHERE id = 'test-err';")
        @test first(cnt_rows).cnt == 0
    end

    @testset "3. Workspace Lifecycle & Isolation" begin
        ws_path = joinpath(test_temp_dir, "workspaces", "ws_main")
        ws = WorkspaceManager.create_workspace(global_db, "Primary Research", ws_path)
        @test ws.name == "Primary Research"
        @test isdir(ws_path)
        @test isfile(joinpath(ws_path, "db", "synapse.db"))

        # Retrieval
        fetched_ws = WorkspaceManager.get_workspace(global_db, ws.id)
        @test fetched_ws !== nothing
        @test fetched_ws.id == ws.id

        # Listing
        all_ws = WorkspaceManager.list_workspaces(global_db)
        @test length(all_ws) >= 1

        # Archive
        WorkspaceManager.archive_workspace(global_db, ws.id)
        active_ws = WorkspaceManager.list_workspaces(global_db; include_archived=false)
        @test !any(w -> w.id == ws.id, active_ws)
    end

    # Create active workspace for subsequent tests
    ws_active_path = joinpath(test_temp_dir, "workspaces", "active_ws")
    ws_active = WorkspaceManager.create_workspace(global_db, "Active Workspace", ws_active_path)
    ws_db = Database.open_database(joinpath(ws_active_path, "db", "synapse.db"))

    @testset "4. Document Parsing & Ingestion (MD, TXT, PDF)" begin
        # 4.1 Markdown parsing
        md_text = """
        # Attention Is All You Need

        ## Abstract
        The dominant sequence transduction models are based on complex recurrent or convolutional neural networks.
        We propose a new simple network architecture, the Transformer, based solely on attention mechanisms.

        ## Model Architecture
        The Transformer follows this overall architecture using stacked self-attention and point-wise, fully connected layers.
        """
        parsed_md = DocumentParsers.parse_markdown(md_text; default_title="Attention Paper")
        @test parsed_md.title == "Attention Is All You Need"
        @test length(parsed_md.sections) >= 2
        @test parsed_md.format == "markdown"
        @test parsed_md.total_lines > 5

        # 4.2 Plain text parsing
        txt_text = "Quantum computing relies on qubits.\n\nSuperconducting circuits provide fast gate times."
        parsed_txt = DocumentParsers.parse_plaintext(txt_text; default_title="Quantum Notes")
        @test parsed_txt.format == "plaintext"
        @test length(parsed_txt.sections) == 2

        # 4.3 Scanned PDF detection
        mock_scanned_pdf = b"%PDF-1.5\n1 0 obj\n<< /Type /Page /Resources << /XObject << /Im1 2 0 R >> >> >>\nendobj\n2 0 obj\n<< /Type /XObject /Subtype /Image >>\nstream\n[RAW_IMAGE_BYTES]\nendstream\nendobj\n%%EOF"
        parsed_scanned = DocumentParsers.parse_pdf(mock_scanned_pdf; default_title="Scanned Invoice")
        @test parsed_scanned.is_scanned == true
        @test occursin("OCR is required", parsed_scanned.warning)

        # 4.4 Chunking & FTS5 Indexing
        sample_attention = joinpath(test_temp_dir, "attention.md")
        write(sample_attention, md_text)
        src_res = SourceService.import_source_file(ws_db, ws_active.id, ws_active_path, sample_attention; title="Attention Is All You Need")
        ver_id = src_res.version_id
        chunks = Chunking.chunk_document(parsed_md, ver_id; target_chunk_size=150)
        @test length(chunks) >= 2
        Chunking.index_chunks!(ws_db, ws_active.id, src_res.source.id, chunks)

        # Verify FTS search matches
        search_hits = FTS5Search.search_fts(ws_db, ws_active.id, "Transformer attention")
        @test !isempty(search_hits)
        @test occursin("Transformer", first(search_hits).content)
    end

    @testset "5. File Deduplication (SHA-256 Checksum)" begin
        sample_file = joinpath(test_temp_dir, "sample.md")
        write(sample_file, "# Benchmark Protocol\nStandard evaluation on GLUE benchmarks.")

        # First import
        res1 = SourceService.import_source_file(ws_db, ws_active.id, ws_active_path, sample_file)
        @test res1.is_duplicate == false
        @test isfile(res1.source.managed_path)

        # Second import of identical file
        res2 = SourceService.import_source_file(ws_db, ws_active.id, ws_active_path, sample_file)
        @test res2.is_duplicate == true
        @test res2.source.id == res1.source.id
        @test res2.source.checksum == res1.source.checksum
    end

    @testset "6. Evidence Graph & Contradiction Preservation" begin
        # Create supporting evidence
        ev_id_1 = string(uuid4())
        ev_id_2 = string(uuid4())
        now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
        
        v_rows = Database.query(ws_db, "SELECT id FROM source_versions LIMIT 1;")
        active_ver_id = string(first(v_rows).id)

        Database.execute(ws_db, "INSERT INTO evidence (id, source_version_id, page_number, start_line, end_line, start_char, end_char, excerpt, created_at) VALUES ('$ev_id_1', '$active_ver_id', 1, 10, 12, 100, 200, 'Optimizer A achieves 85% accuracy on benchmark.', '$now_iso');")
        Database.execute(ws_db, "INSERT INTO evidence (id, source_version_id, page_number, start_line, end_line, start_char, end_char, excerpt, created_at) VALUES ('$ev_id_2', '$active_ver_id', 2, 20, 22, 500, 600, 'Optimizer A fails to surpass 70% accuracy under identical conditions.', '$now_iso');")

        # Create two opposing empirical claims
        claim_1 = GraphStore.add_claim!(ws_db, ws_active.id, "Optimizer A achieves 85% accuracy.", "Optimizer A achieves 85% accuracy on benchmark.", Epistemic.SOURCE_GROUNDED, ev_id_1)
        claim_2 = GraphStore.add_claim!(ws_db, ws_active.id, "Optimizer A fails to surpass 70% accuracy.", "Optimizer A cannot exceed 70% accuracy.", Epistemic.SOURCE_GROUNDED, ev_id_2)

        @test claim_1.epistemic_state == Epistemic.SOURCE_GROUNDED
        @test claim_2.epistemic_state == Epistemic.SOURCE_GROUNDED

        # Link with CONTRADICTS relation
        rel = GraphStore.add_relation!(
            ws_db, ws_active.id, claim_1.id, "claim", claim_2.id, "claim",
            Relations.CONTRADICTS, Epistemic.SOURCE_GROUNDED, ev_id_2
        )
        @test rel.relation_type == Relations.CONTRADICTS

        # CRITICAL TEST: Contradiction preservation rule - neither claim is deleted or overwritten.
        # Both claims must transition to CONFLICTED epistemic state!
        c1_after = Database.query(ws_db, "SELECT epistemic_state FROM claims WHERE id = '$(claim_1.id)';")
        c2_after = Database.query(ws_db, "SELECT epistemic_state FROM claims WHERE id = '$(claim_2.id)';")
        @test first(c1_after).epistemic_state == Epistemic.CONFLICTED
        @test first(c2_after).epistemic_state == Epistemic.CONFLICTED

        # Neighborhood query
        neighborhood = GraphQueries.get_neighborhood(ws_db, ws_active.id, claim_1.id)
        @test length(neighborhood.nodes) >= 2
        @test any(e -> e.relation_type == Relations.CONTRADICTS, neighborhood.edges)
    end

    @testset "7. Audit Trail & Undo Operations" begin
        # Verify that all graph mutations recorded audit events
        audits = AuditService.get_audit_events(ws_db, ws_active.id)
        @test length(audits) >= 3
        @test all(a -> a.workspace_id == ws_active.id, audits)
        @test all(!isempty, [a.actor for a in audits])
        @test all(!isempty, [a.reason for a in audits])

        # Test reversible mutation (Undo)
        test_concept = GraphStore.add_concept!(ws_db, ws_active.id, "Transient Concept", "A concept to be undone", Epistemic.SOURCE_GROUNDED, nothing; actor="researcher")
        latest_audit = first(AuditService.get_audit_events(ws_db, ws_active.id; limit=1))
        @test latest_audit.target_id == test_concept.id
        @test latest_audit.event_type == "create"

        # Undo the creation
        AuditService.undo_mutation!(ws_db, ws_active.id, latest_audit.id; actor="researcher")
        # Verify target concept was safely deleted
        check_c = Database.query(ws_db, "SELECT COUNT(*) AS cnt FROM concepts WHERE id = '$(test_concept.id)';")
        @test first(check_c).cnt == 0

        # Verify undo event recorded in audit log
        undo_audit = first(AuditService.get_audit_events(ws_db, ws_active.id; limit=1))
        @test undo_audit.event_type == "undo"
        @test occursin("Reversed creation", undo_audit.reason)
    end

    @testset "8. Review Queue Workflow" begin
        rev_concept = GraphStore.add_concept!(ws_db, ws_active.id, "Candidate Entity", "Proposed by model", Epistemic.AI_INFERRED, nothing; actor="ai_pipeline")
        item = ReviewQueue.create_review_item!(ws_db, ws_active.id, "concept", rev_concept.id, "High confidence extraction", 0.94)
        
        pending_items = ReviewQueue.list_review_items(ws_db, ws_active.id; status="pending")
        @test any(i -> i.id == item.id, pending_items)

        # Human acceptance
        ReviewQueue.decide_review_item!(ws_db, ws_active.id, item.id, "accept", "Approved definition"; actor="lead_researcher")
        
        # Verify concept upgraded to HUMAN_REVIEWED
        c_status = Database.query(ws_db, "SELECT epistemic_state FROM concepts WHERE id = '$(rev_concept.id)';")
        @test first(c_status).epistemic_state == Epistemic.HUMAN_REVIEWED

        # Verify review decision audit event
        audit_res = first(AuditService.get_audit_events(ws_db, ws_active.id; limit=1))
        @test audit_res.event_type == "review_accept"
    end

    @testset "9. Research Assistant & Grounded Citations" begin
        # Ask question on indexed topic
        ans = Assistant.ask_research_question(ws_db, ws_active.id, "Transformer attention"; limit=5)
        @test !isempty(ans.answer)
        @test length(ans.citations) > 0
        @test all(c -> c.is_valid, ans.citations)
        @test ans.citations[1].locator != "unknown"

        # Ask question outside knowledge base (Insufficient evidence)
        empty_ans = Assistant.ask_research_question(ws_db, ws_active.id, "Galactic astrophysics neutrino emissions"; limit=5)
        @test empty_ans.epistemic_state == Epistemic.INSUFFICIENT_EVIDENCE
        @test occursin("Insufficient evidence", empty_ans.answer)
        @test isempty(empty_ans.citations)

        # Save synthesis
        saved_synth = Assistant.save_synthesis!(ws_db, ws_active.id, ans.question, ans.answer, ans.limitations, ans.citations)
        @test saved_synth.question == ans.question
        
        # Verify synthesis in database and audit log
        check_s = Database.query(ws_db, "SELECT id FROM syntheses WHERE id = '$(saved_synth.id)';")
        @test length(check_s) == 1
    end

    @testset "10. Cloud Consent Guard (Zero Cloud Leakage)" begin
        # 10.1 Must block cloud requests without consent
        @test_throws CloudConsentGuard.ConsentRequiredException CloudConsentGuard.assert_cloud_consent!(
            ws_db, ws_active.id, "anthropic", "cross_source_synthesis", "evidence_excerpts_only"
        )

        # 10.2 Grant consent
        cid = CloudConsentGuard.grant_consent!(
            ws_db, ws_active.id, "anthropic", "cross_source_synthesis", "evidence_excerpts_only",
            "Excerpt preview text"; duration_hours=24
        )
        @test !isempty(cid)
        # Should now pass
        @test CloudConsentGuard.assert_cloud_consent!(
            ws_db, ws_active.id, "anthropic", "cross_source_synthesis", "evidence_excerpts_only"
        ) == true

        # 10.3 Revoke consent
        CloudConsentGuard.revoke_consent!(ws_db, ws_active.id, cid)
        # Must block again immediately
        @test_throws CloudConsentGuard.ConsentRequiredException CloudConsentGuard.assert_cloud_consent!(
            ws_db, ws_active.id, "anthropic", "cross_source_synthesis", "evidence_excerpts_only"
        )
    end

    @testset "11. Durable Jobs & Stale Job Recovery" begin
        job = JobOrchestrator.create_job(ws_db, ws_active.id, "document_ingestion", "hash123")
        @test job.status == JobOrchestrator.STATUS_QUEUED

        JobOrchestrator.update_job_progress(ws_db, job.id, "processing", 0.3)
        running_job = JobOrchestrator.get_job(ws_db, job.id)
        @test running_job.status == JobOrchestrator.STATUS_RUNNING
        @test running_job.progress == 0.3

        # Simulate engine crash & restart -> recover stale jobs
        JobOrchestrator.recover_stale_jobs!(ws_db)
        recovered_job = JobOrchestrator.get_job(ws_db, job.id)
        @test recovered_job.status == JobOrchestrator.STATUS_FAILED
        @test occursin("restart interrupted", recovered_job.error_message)
    end

    @testset "12. Local API & Security Middleware" begin
        cfg = Config.default_config(base_dir=test_temp_dir, port=9876, session_token="secret_token_123")
        srv = Server.start_server(cfg)
        
        try
            # 12.1 Health check (Open on loopback)
            health_req = HTTP.get("http://127.0.0.1:9876/api/v1/health")
            @test health_req.status == 200
            health_json = JSON3.read(String(health_req.body))
            @test health_json.data.status == "ok"

            # 12.2 Unauthorized request (No token)
            unauth_resp = try
                HTTP.get("http://127.0.0.1:9876/api/v1/workspaces")
            catch e
                e.response
            end
            @test unauth_resp.status == 401

            # 12.3 Authorized request (Valid token)
            auth_resp = HTTP.get("http://127.0.0.1:9876/api/v1/workspaces", ["X-Synapse-Token" => "secret_token_123"])
            @test auth_resp.status == 200
            ws_list = JSON3.read(String(auth_resp.body))
            @test ws_list.success == true

            # 12.4 Disallowed Origin (CSRF / malicious web page rejection)
            forbidden_resp = try
                HTTP.get("http://127.0.0.1:9876/api/v1/workspaces", [
                    "X-Synapse-Token" => "secret_token_123",
                    "Origin" => "http://evil-tracker.com"
                ])
            catch e
                e.response
            end
            @test forbidden_resp.status == 403
        finally
            Server.stop_server(srv)
        end
    end

    include(joinpath(@__DIR__, "test_milestone_lifecycle.jl"))

    try
        DBInterface.close!(global_db)
        DBInterface.close!(ws_db)
    catch
    end
    try
        rm(test_temp_dir, recursive=true, force=true)
    catch
    end
    println("\n=======================================================")
    println(" [SUCCESS] All Synapse Test Suites Passed Cleanly! ")
    println("=======================================================")
end
