# Synapse Data Model & Schema Specification

## 1. Domain Entities & Storage Layout

All entities use stable UUIDv4 strings as primary keys. Names and file paths are never used as primary keys.

```text
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│    Workspace    │───1:N─▶│     Source      │───1:N─▶│  SourceVersion  │
└─────────────────┘       └─────────────────┘       └────────┬────────┘
                                                             │ 1:N
                                                             ▼
                                                    ┌─────────────────┐
                                                    │    Evidence     │
                                                    └────────┬────────┘
                                                             │ M:N
       ┌──────────────────┬─────────────────┬────────────────┴────────────────┬─────────────────┐
       ▼                  ▼                 ▼                                 ▼                 ▼
┌─────────────┐    ┌─────────────┐   ┌─────────────┐                   ┌─────────────┐   ┌─────────────┐
│   Concept   │    │    Claim    │   │   Method    │                   │    Study    │   │  Synthesis  │
└──────┬──────┘    └──────┬──────┘   └──────┬──────┘                   └──────┬──────┘   └──────┬──────┘
       │                  │                 │                                 │                 │
       └──────────────────┴─────────────────┼─────────────────────────────────┴─────────────────┘
                                            │
                                            ▼
                                   ┌─────────────────┐
                                   │    Relation     │ (supports, contradicts, qualifies, etc.)
                                   └─────────────────┘
```

## 2. SQLite Tables Specification

### 2.1 `workspaces`
- `id` (TEXT PRIMARY KEY): Stable UUID.
- `name` (TEXT NOT NULL): User-visible name.
- `path` (TEXT NOT NULL UNIQUE): Directory on filesystem.
- `created_at` (TEXT NOT NULL): ISO8601 UTC timestamp.
- `updated_at` (TEXT NOT NULL): ISO8601 UTC timestamp.
- `archived` (INTEGER NOT NULL DEFAULT 0): 0 or 1.

### 2.2 `sources`
- `id` (TEXT PRIMARY KEY): Stable UUID.
- `workspace_id` (TEXT NOT NULL REFERENCES workspaces(id)): Owning workspace.
- `title` (TEXT NOT NULL): Source title or filename.
- `format` (TEXT NOT NULL): 'markdown', 'plaintext', 'pdf'.
- `checksum` (TEXT NOT NULL): SHA-256 hash of original file content.
- `original_path` (TEXT NOT NULL): Path where file was imported from.
- `managed_path` (TEXT NOT NULL): Path within workspace storage.
- `created_at` (TEXT NOT NULL): ISO8601 timestamp.
- `updated_at` (TEXT NOT NULL): ISO8601 timestamp.

### 2.3 `source_versions`
- `id` (TEXT PRIMARY KEY): Stable UUID.
- `source_id` (TEXT NOT NULL REFERENCES sources(id)): Source parent.
- `version_number` (INTEGER NOT NULL): Monotonically increasing version.
- `checksum` (TEXT NOT NULL): Content checksum for this specific version.
- `total_pages` (INTEGER NOT NULL DEFAULT 1): Number of pages (PDF) or 1.
- `total_lines` (INTEGER NOT NULL DEFAULT 0): Line count.
- `total_bytes` (INTEGER NOT NULL DEFAULT 0): Byte length.
- `created_at` (TEXT NOT NULL): ISO8601 timestamp.

### 2.4 `evidence`
- `id` (TEXT PRIMARY KEY): Stable UUID.
- `source_version_id` (TEXT NOT NULL REFERENCES source_versions(id)): Specific immutable version.
- `page_number` (INTEGER): Page number if applicable.
- `start_line` (INTEGER): Start line number (1-indexed).
- `end_line` (INTEGER): End line number.
- `start_char` (INTEGER): Character offset in normalized text.
- `end_char` (INTEGER): Character end offset.
- `excerpt` (TEXT NOT NULL): Verbatim excerpt text from source.
- `extraction_metadata` (TEXT): JSON-encoded metadata (context, parser version).
- `created_at` (TEXT NOT NULL): ISO8601 timestamp.

### 2.5 `chunks_fts` (Virtual FTS5 Table)
- `chunk_id` UNINDEXED
- `source_id` UNINDEXED
- `source_version_id` UNINDEXED
- `page_number` UNINDEXED
- `title`
- `content`

### 2.6 `concepts`
- `id` (TEXT PRIMARY KEY): Stable UUID.
- `workspace_id` (TEXT NOT NULL REFERENCES workspaces(id))
- `name` (TEXT NOT NULL): Canonical concept name.
- `description` (TEXT NOT NULL): Definition / summary.
- `epistemic_state` (TEXT NOT NULL): 'source_grounded', 'ai_inferred', 'human_reviewed'.
- `evidence_id` (TEXT REFERENCES evidence(id)): Grounding evidence if direct.
- `created_at` (TEXT NOT NULL)
- `updated_at` (TEXT NOT NULL)

### 2.7 `claims`
- `id` (TEXT PRIMARY KEY): Stable UUID.
- `workspace_id` (TEXT NOT NULL REFERENCES workspaces(id))
- `original_wording` (TEXT NOT NULL): Direct quote or close verbatim phrasing.
- `normalized_claim` (TEXT NOT NULL): Clean proposition.
- `epistemic_state` (TEXT NOT NULL): 'source_grounded', 'ai_inferred', 'human_reviewed', 'conflicted', 'insufficient_evidence'.
- `evidence_id` (TEXT REFERENCES evidence(id)): Primary grounding evidence.
- `created_at` (TEXT NOT NULL)
- `updated_at` (TEXT NOT NULL)

### 2.8 `methods`
- `id` (TEXT PRIMARY KEY): Stable UUID.
- `workspace_id` (TEXT NOT NULL REFERENCES workspaces(id))
- `name` (TEXT NOT NULL): Algorithm or experimental method.
- `description` (TEXT NOT NULL)
- `evidence_id` (TEXT REFERENCES evidence(id))
- `created_at` (TEXT NOT NULL)

### 2.9 `studies`
- `id` (TEXT PRIMARY KEY): Stable UUID.
- `workspace_id` (TEXT NOT NULL REFERENCES workspaces(id))
- `title` (TEXT NOT NULL)
- `methodology` (TEXT NOT NULL)
- `findings` (TEXT NOT NULL)
- `evidence_id` (TEXT REFERENCES evidence(id))
- `created_at` (TEXT NOT NULL)

### 2.10 `syntheses`
- `id` (TEXT PRIMARY KEY): Stable UUID.
- `workspace_id` (TEXT NOT NULL REFERENCES workspaces(id))
- `question` (TEXT NOT NULL): The research question posed.
- `answer` (TEXT NOT NULL): Evidence-backed response.
- `limitations` (TEXT): Explicit gaps, caveats, or contradictory notes.
- `citation_records` (TEXT NOT NULL): JSON-encoded list of verified citation links.
- `created_at` (TEXT NOT NULL)

### 2.11 `relations`
- `id` (TEXT PRIMARY KEY): Stable UUID.
- `workspace_id` (TEXT NOT NULL REFERENCES workspaces(id))
- `source_node_id` (TEXT NOT NULL): ID of source entity.
- `source_node_type` (TEXT NOT NULL): 'concept', 'claim', 'method', 'study', 'source', 'synthesis'.
- `target_node_id` (TEXT NOT NULL): ID of target entity.
- `target_node_type` (TEXT NOT NULL)
- `relation_type` (TEXT NOT NULL): 'supports', 'contradicts', 'qualifies', 'derived_from', 'uses_method', 'evaluated_on', 'extends', 'related_to'.
- `epistemic_state` (TEXT NOT NULL): 'source_grounded', 'ai_inferred', 'human_reviewed'.
- `provenance_id` (TEXT REFERENCES evidence(id)): Evidence supporting the relation.
- `created_at` (TEXT NOT NULL)

### 2.12 `processing_jobs`
- `id` (TEXT PRIMARY KEY): Stable UUID.
- `workspace_id` (TEXT NOT NULL REFERENCES workspaces(id))
- `job_type` (TEXT NOT NULL): 'document_ingestion', 'extraction', 'synthesis'.
- `input_fingerprint` (TEXT NOT NULL): Hash of job arguments.
- `pipeline_version` (TEXT NOT NULL): E.g., '1.0.0'.
- `status` (TEXT NOT NULL): 'queued', 'running', 'retry_wait', 'cancel_requested', 'cancelled', 'succeeded', 'failed'.
- `progress` (REAL NOT NULL DEFAULT 0.0): 0.0 to 1.0.
- `stage` (TEXT NOT NULL): Current step description.
- `attempts` (INTEGER NOT NULL DEFAULT 0): Retry count.
- `error_message` (TEXT)
- `output_references` (TEXT): JSON-encoded IDs of created entities.
- `created_at` (TEXT NOT NULL)
- `updated_at` (TEXT NOT NULL)

### 2.13 `audit_events`
- `id` (TEXT PRIMARY KEY): Stable UUID.
- `workspace_id` (TEXT NOT NULL REFERENCES workspaces(id))
- `correlation_id` (TEXT NOT NULL): Links related mutations.
- `actor` (TEXT NOT NULL): 'system', 'user', 'ai_pipeline'.
- `target_id` (TEXT NOT NULL): ID of entity touched.
- `target_type` (TEXT NOT NULL): Entity name ('concept', 'claim', 'relation', etc.).
- `event_type` (TEXT NOT NULL): 'create', 'update', 'delete', 'review_accept', 'review_reject', 'undo'.
- `before_state` (TEXT): JSON snapshot prior to mutation (if any).
- `after_state` (TEXT): JSON snapshot after mutation.
- `reason` (TEXT NOT NULL): Rationale for mutation.
- `created_at` (TEXT NOT NULL)

### 2.14 `consent_records`
- `id` (TEXT PRIMARY KEY): Stable UUID.
- `workspace_id` (TEXT NOT NULL REFERENCES workspaces(id))
- `provider` (TEXT NOT NULL): E.g., 'anthropic', 'openai'.
- `purpose` (TEXT NOT NULL): E.g., 'cross_source_synthesis'.
- `scope` (TEXT NOT NULL): E.g., 'evidence_excerpts_only'.
- `payload_preview` (TEXT NOT NULL): Text preview shown to user.
- `granted_at` (TEXT NOT NULL): ISO8601 timestamp.
- `valid_until` (TEXT NOT NULL): ISO8601 timestamp.
- `revoked` (INTEGER NOT NULL DEFAULT 0): 0 or 1.

### 2.15 `review_items`
- `id` (TEXT PRIMARY KEY): Stable UUID.
- `workspace_id` (TEXT NOT NULL REFERENCES workspaces(id))
- `entity_type` (TEXT NOT NULL): 'concept', 'claim', 'relation'.
- `entity_id` (TEXT NOT NULL): ID of candidate entity.
- `rationale` (TEXT NOT NULL): Model explanation for candidate extraction.
- `confidence` (REAL NOT NULL DEFAULT 0.0): Calibrated confidence score.
- `status` (TEXT NOT NULL): 'pending', 'accepted', 'rejected'.
- `created_at` (TEXT NOT NULL)
- `reviewed_at` (TEXT)
