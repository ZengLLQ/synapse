# Synapse Product Specification

## 1. Executive Summary

Synapse is a local-first desktop research assistant that connects technical literature (PDFs, Markdown, and TXT notes) into a traceable, self-evolving evidence graph. Designed for researchers, computer scientists, and software engineers, Synapse emphasizes grounded truth, transparent citations, accountable autonomy, and contradiction preservation over opaque AI confidence.

## 2. Target Persona & Use Cases

- **Machine Learning & AI Researchers**: Synthesizing experimental results across dozens of papers, tracking conflicting benchmark claims, and verifying exact citation spans.
- **Computer Science Graduate Students**: Structuring literature reviews, mapping conceptual relationships, and retaining exact quotes for thesis references.
- **Systems & Software Engineers**: Ingesting complex whitepapers and architecture specifications, isolating foundational methods, and tracking design tradeoffs.

## 3. Core Research Loop

1. **Ingest**: Import text PDFs, Markdown documents, and TXT notes into a designated local workspace. Automatic SHA-256 deduplication prevents redundant processing.
2. **Understand**: Content is parsed into structural sections, chunks, and exact character/line/page locators. Full-text indexing is performed into SQLite FTS5.
3. **Connect**: Entity recognition extracts Concepts, Claims, Methods, and Studies. Relations (`supports`, `contradicts`, `qualifies`, `derived_from`, `uses_method`, `evaluated_on`, `extends`, `related_to`) are linked with strict type compatibility.
4. **Investigate**: Search across the collection via keyword queries or semantic intent. Traverse neighborhoods in the interactive evidence graph.
5. **Synthesize**: Ask cross-document research questions. Synapse retrieves relevant evidence spans, validates grounding, identifies conflicting claims across sources, and produces a synthesis with verifiable citations.
6. **Preserve**: Save syntheses as first-class domain nodes in the knowledge graph. Every graph mutation and review decision is captured in a durable, append-only audit trail with undo support.

## 4. MVP Functional Scope

| Feature | In Scope (MVP) | Out of Scope (Post-MVP) |
|---|---|---|
| Document Ingestion | Text PDF, Markdown, Plain Text (.txt) | Scanned OCR processing, DOCX, ePub |
| Knowledge Model | Concepts, Claims, Methods, Studies, Syntheses, Relations | Multi-tenant team roles |
| Epistemic States | source_grounded, ai_inferred, human_reviewed, conflicted, insufficient_evidence | Real-time collaborative graph editing |
| Retrieval | Full-text SQLite FTS5 with BM25, semantic interface | Universal web scraping |
| Citations | Strict validation against real source & evidence IDs | Automated paper generation |
| Conflict Handling | Preserves opposing claims linked by `contradicts` | Silent consensus forcing |
| Security & Privacy | Loopback-only API, session auth token, explicit cloud consent | Public cloud hosting |
| Auditability | Append-only audit log, reversible graph mutations | Blockchain/merkle proofs |
