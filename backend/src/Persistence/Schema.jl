module Schema

const CURRENT_SCHEMA_VERSION = 1

const DDL_STATEMENTS = [
    """
    CREATE TABLE IF NOT EXISTS schema_version (
        version INTEGER PRIMARY KEY,
        applied_at TEXT NOT NULL
    );
    """,

    """
    CREATE TABLE IF NOT EXISTS workspaces (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        path TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        archived INTEGER NOT NULL DEFAULT 0
    );
    """,

    """
    CREATE TABLE IF NOT EXISTS sources (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        format TEXT NOT NULL,
        checksum TEXT NOT NULL,
        original_path TEXT NOT NULL,
        managed_path TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );
    """,
    "CREATE INDEX IF NOT EXISTS idx_sources_ws_chk ON sources(workspace_id, checksum);",

    """
    CREATE TABLE IF NOT EXISTS source_versions (
        id TEXT PRIMARY KEY,
        source_id TEXT NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
        version_number INTEGER NOT NULL,
        checksum TEXT NOT NULL,
        total_pages INTEGER NOT NULL DEFAULT 1,
        total_lines INTEGER NOT NULL DEFAULT 0,
        total_bytes INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
    );
    """,
    "CREATE INDEX IF NOT EXISTS idx_source_versions_src ON source_versions(source_id);",

    """
    CREATE TABLE IF NOT EXISTS evidence (
        id TEXT PRIMARY KEY,
        source_version_id TEXT NOT NULL REFERENCES source_versions(id) ON DELETE CASCADE,
        page_number INTEGER,
        start_line INTEGER,
        end_line INTEGER,
        start_char INTEGER,
        end_char INTEGER,
        excerpt TEXT NOT NULL,
        extraction_metadata TEXT,
        created_at TEXT NOT NULL
    );
    """,
    "CREATE INDEX IF NOT EXISTS idx_evidence_version ON evidence(source_version_id);",

    """
    CREATE TABLE IF NOT EXISTS chunks (
        id TEXT PRIMARY KEY,
        source_version_id TEXT NOT NULL REFERENCES source_versions(id) ON DELETE CASCADE,
        chunk_index INTEGER NOT NULL,
        page_number INTEGER,
        start_line INTEGER,
        end_line INTEGER,
        start_char INTEGER,
        end_char INTEGER,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL
    );
    """,
    "CREATE INDEX IF NOT EXISTS idx_chunks_srcver ON chunks(source_version_id);",

    """
    CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
        chunk_id UNINDEXED,
        source_id UNINDEXED,
        source_version_id UNINDEXED,
        workspace_id UNINDEXED,
        page_number UNINDEXED,
        title,
        content
    );
    """,

    """
    CREATE TABLE IF NOT EXISTS concepts (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        epistemic_state TEXT NOT NULL,
        evidence_id TEXT REFERENCES evidence(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );
    """,
    "CREATE INDEX IF NOT EXISTS idx_concepts_ws ON concepts(workspace_id);",

    """
    CREATE TABLE IF NOT EXISTS claims (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        original_wording TEXT NOT NULL,
        normalized_claim TEXT NOT NULL,
        epistemic_state TEXT NOT NULL,
        evidence_id TEXT REFERENCES evidence(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );
    """,
    "CREATE INDEX IF NOT EXISTS idx_claims_ws ON claims(workspace_id);",

    """
    CREATE TABLE IF NOT EXISTS methods (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        evidence_id TEXT REFERENCES evidence(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL
    );
    """,

    """
    CREATE TABLE IF NOT EXISTS studies (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        methodology TEXT NOT NULL,
        findings TEXT NOT NULL,
        evidence_id TEXT REFERENCES evidence(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL
    );
    """,

    """
    CREATE TABLE IF NOT EXISTS syntheses (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        question TEXT NOT NULL,
        answer TEXT NOT NULL,
        limitations TEXT,
        citation_records TEXT NOT NULL,
        created_at TEXT NOT NULL
    );
    """,

    """
    CREATE TABLE IF NOT EXISTS relations (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        source_node_id TEXT NOT NULL,
        source_node_type TEXT NOT NULL,
        target_node_id TEXT NOT NULL,
        target_node_type TEXT NOT NULL,
        relation_type TEXT NOT NULL,
        epistemic_state TEXT NOT NULL,
        provenance_id TEXT REFERENCES evidence(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL
    );
    """,
    "CREATE INDEX IF NOT EXISTS idx_relations_src ON relations(source_node_id);",
    "CREATE INDEX IF NOT EXISTS idx_relations_tgt ON relations(target_node_id);",
    "CREATE INDEX IF NOT EXISTS idx_relations_type ON relations(relation_type);",

    """
    CREATE TABLE IF NOT EXISTS processing_jobs (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        job_type TEXT NOT NULL,
        input_fingerprint TEXT NOT NULL,
        pipeline_version TEXT NOT NULL,
        status TEXT NOT NULL,
        progress REAL NOT NULL DEFAULT 0.0,
        stage TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        error_message TEXT,
        output_references TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );
    """,
    "CREATE INDEX IF NOT EXISTS idx_jobs_ws_status ON processing_jobs(workspace_id, status);",

    """
    CREATE TABLE IF NOT EXISTS audit_events (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        correlation_id TEXT NOT NULL,
        actor TEXT NOT NULL,
        target_id TEXT NOT NULL,
        target_type TEXT NOT NULL,
        event_type TEXT NOT NULL,
        before_state TEXT,
        after_state TEXT,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL
    );
    """,
    "CREATE INDEX IF NOT EXISTS idx_audit_ws_time ON audit_events(workspace_id, created_at);",

    """
    CREATE TABLE IF NOT EXISTS consent_records (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        provider TEXT NOT NULL,
        purpose TEXT NOT NULL,
        scope TEXT NOT NULL,
        payload_preview TEXT NOT NULL,
        granted_at TEXT NOT NULL,
        valid_until TEXT NOT NULL,
        revoked INTEGER NOT NULL DEFAULT 0
    );
    """,
    "CREATE INDEX IF NOT EXISTS idx_consent_lookup ON consent_records(workspace_id, provider, revoked);",

    """
    CREATE TABLE IF NOT EXISTS review_items (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        rationale TEXT NOT NULL,
        confidence REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        reviewed_at TEXT
    );
    """,
    "CREATE INDEX IF NOT EXISTS idx_review_ws_status ON review_items(workspace_id, status);"
]

end # module Schema
