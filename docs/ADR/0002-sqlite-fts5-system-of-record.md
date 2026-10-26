# ADR 0002: SQLite with FTS5 as System-of-Record

## Status
Accepted

## Context
Synapse needs reliable, persistent storage for document metadata, versions, graph entities, relations, durable jobs, consent records, and audit events. We also need full-text search across document chunks. Options considered: separate graph database (Neo4j), separate search index (Meilisearch/Elastic), or embedded SQLite.

## Decision
We chose **SQLite 3 with FTS5 virtual tables** as the sole system-of-record for the MVP.

## Rationale
- Zero external daemon requirements: SQLite is embedded in-process via `SQLite.jl`, making installation and portability seamless across Windows, macOS, and Linux.
- Strong transactional guarantees (`ACID`, Write-Ahead Logging `WAL`) allow co-locating graph mutations and audit event writes in the exact same database transaction.
- SQLite's FTS5 module provides fast, built-in BM25 ranking for keyword retrieval across document chunks without managing synchronization between separate search engines.
- Graph traversals within personal literature collections (thousands to tens of thousands of nodes) run in sub-millisecond times with indexed SQL joins.

## Consequences
- Specialized graph databases (e.g. Neo4j, Kuzu) are deferred until empirical benchmarks demonstrate SQLite join limitations.
