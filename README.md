# Synapse

> *"Your knowledge, connected. Your conclusions, traceable."*

Synapse is a **local-first desktop research environment and evidence-graph knowledge engine** that transforms technical documents into a continuously evolving, traceable knowledge graph.

It helps technical researchers connect documents, concepts, methods, claims, and evidence; investigate questions across a personal collection; compare conflicting sources; and preserve conclusions with explicit provenance.

---

## Key Differentiators

- **Evidence-First Knowledge Representation**: Concepts and claims are backed by exact source locators and verbatim excerpts.
- **Traceable Citations**: Every claim links directly back to its originating document, page/line locator, and version hash.
- **Cross-Source Contradiction Preservation**: Conflicting scientific claims never overwrite each other; opposing evidence is surfaced and connected via `contradicts` relations.
- **Accountable Autonomy**: AI-generated extractions are staged as candidates in a Review Queue. Graph mutations produce immutable audit events with undo support.
- **Zero Cloud Leakage**: Local-first by default. External cloud providers are strictly blocked without explicit, user-granted scoped consent.

---

## Architecture Overview

Synapse is structured as a modular monolith:

- **Primary Engine (`backend/`)**: Written in **Julia**, owning domain entities, knowledge graph operations, SQLite persistence, FTS5 retrieval, document parsing (Markdown, Plain Text, PDF text streams), research synthesis, and API serving (`HTTP.jl`).
- **Desktop Shell (`desktop/`)**: Built with **Tauri 2** (Rust shell) + **React** and **TypeScript** (presentation layer, graph visualization, reading interface, and research studio).
- **Process Boundary**: The Julia engine runs as a managed local process listening strictly on loopback (`127.0.0.1`), authenticated by an ephemeral session token (`X-Synapse-Token`) and verified Origin headers.

---

## Repository Structure

```text
synapse/
├── backend/                  # Julia core engine
│   ├── Project.toml          # Environment & dependency definitions
│   ├── src/                  # Modular monolith modules
│   │   ├── Synapse.jl        # Main entrypoint & service orchestrator
│   │   ├── Application/      # App lifecycle & configuration
│   │   ├── Workspace/        # Workspace management & isolation
│   │   ├── Sources/          # Source identity, checksums & deduplication
│   │   ├── Ingestion/        # Document parsers (MD, TXT, PDF) & chunkers
│   │   ├── Domain/           # Typed entities, claims, relations, epistemic states
│   │   ├── Provenance/       # Evidence references & locators
│   │   ├── Graph/            # Graph queries, traversals & mutations
│   │   ├── Retrieval/        # FTS5 full-text search & semantic interfaces
│   │   ├── Research/         # Cross-source question answering & synthesis
│   │   ├── Models/           # Provider-neutral model adapters & consent guards
│   │   ├── Jobs/             # Durable job queue & execution state machine
│   │   ├── Audit/            # Immutable audit trail & review queue
│   │   ├── Persistence/      # SQLite repositories, schema & migrations
│   │   ├── Export/           # Workspace export & backup restoration
│   │   └── API/              # Loopback HTTP server & REST handlers
│   ├── test/                 # Automated test suite (unit, integration, security)
│   └── benchmarks/           # Human-labeled benchmark suite (precision, citation F1)
├── desktop/                  # Tauri 2 + React/TypeScript desktop frontend
│   ├── src/                  # UI components, features, graph renderer, reader
│   └── src-tauri/            # Tauri 2 Rust desktop configuration
├── docs/                     # Specifications, ADRs, security & architecture guides
└── scripts/                  # Development & verification automation scripts
```

---

## Quickstart & Verification

### 1. Prerequisites
- **Julia** >= 1.10 (tested on Julia 1.13.3)
- **Node.js** >= 20 (tested on Node 26.7.0)
- **Rust / Cargo** >= 1.75 (tested on Cargo 1.98.0)

### 2. Running Julia Backend Tests
Run the complete automated test suite (domain invariants, SQLite persistence, parsers, graph queries, audit trail, research synthesis, and security boundaries):

```bash
cd backend
julia --project=. test/runtests.jl
```

### 3. Running Research Quality Benchmarks
Run the evaluation suite measuring citation validity, retrieval Precision@5, entity/relation extraction F1, and cloud consent enforcement:

```bash
cd backend
julia --project=. benchmarks/run_benchmarks.jl
```

### 4. Running Backend API Server
```bash
cd backend
julia --project=. -e "using Synapse; Synapse.start_server(port=8765)"
```

### 5. Running Desktop UI in Development
```bash
cd desktop
npm install
npm run dev
```

---

## Documentation

- [Product Specification](docs/PRODUCT_SPEC.md)
- [System Design Baseline](docs/SYSTEM_DESIGN.md)
- [Technical Architecture](docs/TECHNICAL_ARCHITECTURE.md)
- [Security & Consent Model](docs/SECURITY_MODEL.md)
- [Data Model & SQLite Schema](docs/DATA_MODEL.md)
- [API Contract & Schema](docs/API_CONTRACT.md)
- [Benchmarks & Evaluation Results](docs/BENCHMARKS.md)
- [Architecture Decision Records (ADR)](docs/ADR/)

---

## Known Limitations

- **Scanned / Image-Only PDFs**: Text extraction currently supports text-based PDF streams. Scanned PDFs without embedded text streams are detected and flagged for OCR, which requires an external OCR utility not bundled in the initial MVP.
- **Single-User Local Focus**: Synapse MVP is optimized for single-user desktop research. Multi-user concurrent editing and remote server deployments are deliberately out of scope for v0.1.
- **Local Embedding Latency**: High-dimensional neural embeddings on CPU-only machines may require batching; a lightweight BM25/keyword retrieval fallback is always available offline.
