# Synapse System Design Baseline

## 1. System Overview

Synapse is designed as a local-first desktop application composed of two primary operating components:
1. **Julia Core Modular Monolith**: Owns the knowledge model, SQLite persistence, FTS5 index, document parsers, graph algorithms, evidence retrieval, cross-source synthesis, audit trail, and loopback REST API.
2. **Desktop Shell & Presentation Layer**: Tauri 2 (Rust wrapper) hosting a React + TypeScript single-page application. Handles user interactions, visual layout, graph rendering, and document viewing.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Tauri 2 Desktop Shell                           │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                React + TypeScript UI Presentation                 │  │
│  │  - Workspace Home      - Interactive Graph Explorer               │  │
│  │  - Sources & Reader    - Research Studio & Review Queue           │  │
│  └─────────────────────────────────▲────────────────────────────────┘  │
│                                    │ HTTP / JSON (127.0.0.1)           │
│                                    │ Auth Token: X-Synapse-Token       │
│                                    ▼                                   │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                     Julia Engine Process                         │  │
│  │  - Application & API (HTTP.jl)                                   │  │
│  │  - Workspace & Sources (SHA-256 deduplication)                   │  │
│  │  - Ingestion Pipeline (MD, TXT, PDF Text Streams)                │  │
│  │  - Knowledge Domain & Graph Engine                               │  │
│  │  - Retrieval Engine (SQLite FTS5 BM25 + Semantic Interface)      │  │
│  │  - Research Assistant & Citation Grounding Validator             │  │
│  │  - Model Adapters (Local Mock / Local LLM / Cloud with Consent)  │  │
│  │  - Durable Jobs & Append-Only Audit Log                          │  │
│  └─────────────────────────────────▲────────────────────────────────┘  │
│                                    │ SQL Queries & Transactions        │
│                                    ▼                                   │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                   SQLite System-of-Record                        │  │
│  │  - Schema & Foreign Keys       - FTS5 Virtual Tables             │  │
│  │  - Workspaces & Sources        - Entities & Relations            │  │
│  │  - Audit Events & Jobs         - Consent Records                 │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

## 2. Process Boundary & Security Design

- **Loopback Binding**: The Julia engine process binds strictly to `127.0.0.1` on a dynamically allocated or configured port.
- **Session Authentication**: The desktop shell passes a cryptographically generated 256-bit random session token on startup via the `X-Synapse-Token` header. Every endpoint validates this header.
- **Origin Checking**: The engine verifies that incoming requests originate from `tauri://localhost`, `http://localhost`, or `http://127.0.0.1`.
- **Process Supervision**: Tauri starts the Julia child process on launch, monitors its health via `/api/v1/health`, and ensures clean shutdown on application exit.

## 3. Persistence Strategy

- SQLite is used as the sole system-of-record.
- Foreign keys and WAL (Write-Ahead Logging) mode are enabled for transaction isolation and fast concurrent reads.
- Full-text search is powered by SQLite's FTS5 virtual tables with BM25 ranking.
- Raw document files are kept in managed workspace storage (`workspaces/<workspace_id>/sources/`), indexed by cryptographic SHA-256 hashes.
