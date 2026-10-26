# Changelog

All notable changes to Synapse are documented in this file.

## [0.1.0] - 2026-10-26 - MVP Release

### Added
- **Core Knowledge Engine (Julia)**:
  - Modular monolith architecture (`Application`, `Workspace`, `Sources`, `Ingestion`, `Domain`, `Provenance`, `Graph`, `Retrieval`, `Research`, `Models`, `Jobs`, `Audit`, `Persistence`, `Export`, `API`).
  - Durable SQLite system-of-record with schema versioning and atomic transactions.
  - Document ingestion engine supporting Markdown, Plain Text, and text-based PDF formats with locator offsets.
  - Scanned PDF detection explaining OCR requirement without claiming false extraction success.
  - Full-text keyword search powered by SQLite FTS5 with BM25 ranking.
  - Typed epistemic knowledge graph (`Source`, `Concept`, `Claim`, `Method`, `Study`, `Synthesis`) with typed relations (`supports`, `contradicts`, `qualifies`, etc.).
  - Immutable audit trail recording every graph mutation, review action, and undo step.
  - Review Queue for candidate AI-inferred entities and relations.
  - Research Assistant generating evidence-grounded synthesis with verified citations and contradiction detection.
  - Provider-neutral model adapter architecture with local mock/heuristic adapter and explicit cloud consent gate.
  - Loopback-bound authenticated REST API (`HTTP.jl`) protected by per-session token and origin checking.
- **Desktop Shell (Tauri 2 + React + TypeScript)**:
  - Polished research-grade UI: Workspace Home, Source Manager, Document Reader, Interactive Evidence Graph, Research Studio, Candidate Review Queue, Activity/Audit Timeline, and Settings/Consent Center.
- **Evaluation & Benchmarks**:
  - Unit, integration, and security test suites in Julia.
  - Human-labeled benchmark suite evaluating citation validity, retrieval precision, entity/relation extraction F1, and audit completeness.
