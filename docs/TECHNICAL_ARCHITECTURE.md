# Technical Architecture

## 1. Primary Technology Selections & Rationale

| Component | Technology | Rationale |
|---|---|---|
| Domain Logic & Processing Engine | **Julia 1.10+** (1.13 tested) | High-performance numerical and text processing, rich type system, first-class mathematical primitives, strong metaprogramming. |
| Persistence & Full-Text Search | **SQLite 3 + FTS5** (`SQLite.jl`, `DBInterface.jl`) | Embedded, zero-dependency, crash-resilient transactional storage with built-in BM25 full-text ranking. No external database daemon needed. |
| Local HTTP / REST API | **`HTTP.jl`** | Lightweight, high-throughput HTTP server in pure Julia with streaming and loopback support. |
| Serialization | **`JSON3.jl`** | Extremely fast, zero-allocation JSON parsing and encoding in Julia. |
| Desktop Shell | **Tauri 2 (Rust)** | Negligible memory footprint (<40MB baseline vs >200MB in Electron), native OS windowing, secure IPC. |
| Desktop UI | **React 18 + TypeScript + Vite + Tailwind CSS** | Clean developer ergonomics, strong component ecosystem, typed API contracts, responsive rendering. |
| Text PDF Parsing | **Native Julia Stream Parser + `libz`** | Zero-dependency text extraction directly leveraging Julia's bundled `libz` for FlateDecode decompression, font-stream mapping, and OCR detection. |

## 2. Julia Module Structure

All backend modules live under `backend/src/` with clean boundaries:

```text
backend/src/
├── Synapse.jl               # Module root and re-exports
├── Application/
│   └── Config.jl            # Configuration, paths, environment flags
├── Workspace/
│   └── WorkspaceManager.jl  # Workspace directory & lifecycle management
├── Sources/
│   └── SourceService.jl     # File validation, SHA-256 deduplication, versioning
├── Ingestion/
│   ├── DocumentParsers.jl   # MD, TXT, PDF text stream parsers
│   └── Chunking.jl          # Deterministic chunking & locator calculation
├── Domain/
│   ├── Entities.jl          # Core structs: Concept, Claim, Method, Study, Synthesis
│   ├── Relations.jl         # Relation types, validation & compatibility matrices
│   └── Epistemic.jl         # Epistemic states (source_grounded, ai_inferred, conflicted)
├── Provenance/
│   └── ProvenanceTracker.jl # Evidence spans, source version links, locator offsets
├── Graph/
│   ├── GraphStore.jl        # SQLite-backed graph operations & mutations
│   └── GraphQueries.jl      # Traversal, neighborhood exploration, filtering
├── Retrieval/
│   ├── FTS5Search.jl        # Full-text keyword retrieval with BM25
│   └── HybridRetriever.jl   # Fused keyword & semantic retrieval interface
├── Research/
│   ├── Assistant.jl         # Cross-source question answering & synthesis
│   └── CitationValidator.jl # Verifies citation grounding against source locators
├── Models/
│   ├── ModelAdapters.jl     # Provider-neutral model interface
│   ├── MockAdapter.jl       # Deterministic heuristic adapter for offline/testing
│   └── CloudConsentGuard.jl # Enforces explicit user consent before cloud egress
├── Jobs/
│   └── JobOrchestrator.jl   # Durable SQLite job queue, retries, cancellation
├── Audit/
│   ├── AuditService.jl      # Append-only audit logging & reversible mutations
│   └── ReviewQueue.jl       # Staging & approval workflow for candidate extractions
├── Persistence/
│   ├── Database.jl          # Connection pooling, WAL mode, migrations
│   └── Schema.jl            # DDL definitions & table initializations
├── Export/
│   └── WorkspaceExport.jl   # JSON/ZIP workspace backup & restoration
└── API/
    ├── Server.jl            # HTTP.jl server loop, loopback binding, auth token
    └── Routes.jl            # REST endpoints mapping to internal services
```

## 3. Invariants & Architecture Enforcement

1. **Unidirectional Dependency Flow**: The API layer depends on Domain and Service modules; Domain and Service modules depend on Persistence; Domain never imports API or UI code.
2. **Transaction Isolation**: Any state mutation affecting the knowledge graph, source versions, or jobs is executed inside an explicit SQLite transaction.
3. **Audit Event Co-Location**: Every graph mutation records an `AuditEvent` inside the *same* database transaction, guaranteeing that un-audited state changes cannot occur.
4. **Idempotent Ingestion**: Ingesting the identical file twice produces a deduplication reference to the existing source without creating duplicated graph entities.
