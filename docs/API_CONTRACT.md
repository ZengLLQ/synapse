# Synapse Local API Contract (v1)

The Julia engine listens exclusively on loopback (`http://127.0.0.1:<port>`).
All requests require the `X-Synapse-Token: <session_token>` header.

## 1. Response Envelope Format

All responses adhere to the standard envelope format:

### Success Response (`200 OK`, `201 Created`):
```json
{
  "success": true,
  "data": { ... },
  "error": null
}
```

### Error Response (`400`, `401`, `403`, `404`, `500`):
```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "CONSENT_REQUIRED",
    "message": "Cloud inference requires active user consent.",
    "details": { ... }
  }
}
```

---

## 2. API Endpoints

### 2.1 Health & Diagnostics
- `GET /api/v1/health`
  - Returns engine status, version, uptime, and database connection state.

### 2.2 Workspaces
- `GET /api/v1/workspaces`
  - List all active and archived workspaces.
- `POST /api/v1/workspaces`
  - Body: `{"name": "ML Literature Review", "path": "/path/to/workspace"}`
  - Creates and initializes a new local workspace SQLite database.
- `GET /api/v1/workspaces/:id`
  - Get workspace metadata and statistics.

### 2.3 Sources & Ingestion
- `GET /api/v1/workspaces/:workspace_id/sources`
  - List imported sources in the workspace.
- `POST /api/v1/workspaces/:workspace_id/sources/import`
  - Body: `{"file_path": "/path/to/paper.pdf"}`
  - Validates file, computes SHA-256 checksum, copies to managed workspace storage, creates source version, and dispatches an ingestion job. Returns `{ "job_id": "...", "source_id": "..." }`.
- `GET /api/v1/workspaces/:workspace_id/sources/:source_id`
  - Returns source metadata, versions, and total pages/lines.
- `GET /api/v1/workspaces/:workspace_id/sources/:source_id/content`
  - Returns full extracted content and evidence locators.

### 2.4 Jobs & Progress
- `GET /api/v1/workspaces/:workspace_id/jobs/:job_id`
  - Returns job status (`queued`, `running`, `succeeded`, `failed`, `cancelled`), current stage, progress (0.0-1.0), and error message if failed.
- `POST /api/v1/workspaces/:workspace_id/jobs/:job_id/cancel`
  - Cooperatively requests cancellation of a running job.

### 2.5 Search & Retrieval
- `GET /api/v1/workspaces/:workspace_id/search?q=<query>&limit=10`
  - Executes full-text FTS5 BM25 search across indexed chunks. Returns matched chunks with snippet highlights and source locators.

### 2.6 Evidence Graph
- `GET /api/v1/workspaces/:workspace_id/graph`
  - Query params: `node_types`, `relation_types`, `limit`
  - Returns graph nodes (Concepts, Claims, Methods, Studies, Sources) and directed edges (Relations) with epistemic state badges.
- `GET /api/v1/workspaces/:workspace_id/graph/neighborhood/:node_id?depth=1`
  - Returns bounded ego-graph around the selected node with attached evidence records.
- `POST /api/v1/workspaces/:workspace_id/graph/undo`
  - Body: `{"audit_event_id": "..."}`
  - Reverses a specific graph mutation while recording a compensating audit event.

### 2.7 Research Studio & Question Answering
- `POST /api/v1/workspaces/:workspace_id/research/ask`
  - Body: `{"question": "How does LoRA reduce trainable parameters compared to full fine-tuning?"}`
  - Executes retrieval, evidence selection, cross-source synthesis, citation verification, and contradiction detection.
  - Returns `{ "answer": "...", "citations": [...], "conflicts": [...], "limitations": "..." }`.
- `POST /api/v1/workspaces/:workspace_id/research/save_synthesis`
  - Body: `{"question": "...", "answer": "...", "citations": [...]}`
  - Persists synthesis as a domain node and creates an audit event.

### 2.8 Review Queue
- `GET /api/v1/workspaces/:workspace_id/review`
  - List candidate entities and relations pending human approval.
- `POST /api/v1/workspaces/:workspace_id/review/:review_id/decide`
  - Body: `{"action": "accept" | "reject", "notes": "..."}`
  - Transition candidate epistemic state to `human_reviewed` or archived.

### 2.9 Activity & Audit Log
- `GET /api/v1/workspaces/:workspace_id/audit`
  - Returns immutable timeline of graph mutations and user review decisions.

### 2.10 Cloud Consent & Settings
- `GET /api/v1/workspaces/:workspace_id/consent`
  - List active and revoked cloud consent grants.
- `POST /api/v1/workspaces/:workspace_id/consent/grant`
  - Body: `{"provider": "anthropic", "purpose": "cross_source_synthesis", "scope": "evidence_excerpts_only", "duration_hours": 24}`
  - Records user consent for cloud execution.
- `POST /api/v1/workspaces/:workspace_id/consent/revoke`
  - Body: `{"consent_id": "..."}`
  - Immediately revokes cloud permission.
