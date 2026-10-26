# Contributing to Synapse

Thank you for contributing to Synapse, the local-first research environment and evidence-graph engine.

## Non-Negotiable Core Principles

1. **Julia Core**: All domain logic, graph manipulation, persistence, provenance, and audit rules belong in the Julia backend (`backend/src/`).
2. **Local-First & Privacy**: No user content, embeddings, or queries may ever leave the user's machine without explicit, scoped, interactive consent.
3. **Traceability & Grounding**: Every claim, relation, and synthesis must trace directly back to verified source evidence with stable locators.
4. **Contradiction Preservation**: Incompatible scientific claims must never be silently flattened or overwritten. Both sides must be preserved with a `contradicts` relation.
5. **Durable Auditing**: Every graph mutation records an immutable audit event.

## Development Workflow

### Prerequisites
- Julia >= 1.10 (tested with Julia 1.13)
- Node.js >= 20 (tested with Node 26)
- Cargo / Rust (for Tauri 2 desktop shell)

### Backend Development
```bash
cd backend
julia --project=. -e "using Pkg; Pkg.instantiate()"
julia --project=. test/runtests.jl
```

### Desktop Frontend Development
```bash
cd desktop
npm install
npm run dev
```

### Running Full-Stack in Dev
To run the Julia API service:
```bash
julia --project=backend backend/src/Synapse.jl --serve --port 8765
```
And launch the Tauri desktop UI:
```bash
cd desktop
npm run tauri dev
```
