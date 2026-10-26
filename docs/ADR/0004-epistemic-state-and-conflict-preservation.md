# ADR 0004: Epistemic States and Contradiction Preservation

## Status
Accepted

## Context
Scientific and technical research frequently involves conflicting empirical results, competing theories, and evolving methodologies. Conventional LLM tools tend to force false consensus, picking whichever assertion sounds most confident or recent, and silently erasing opposing claims.

## Decision
Synapse introduces explicit **epistemic states** (`source_grounded`, `ai_inferred`, `human_reviewed`, `conflicted`, `insufficient_evidence`) and enforces a strict **Contradiction Preservation Policy**.

## Rationale
- Knowledge cannot be reduced to a single floating-point confidence score.
- When an imported source presents a claim contradicting an existing claim in the knowledge graph, Synapse creates a `contradicts` relation between them and updates their epistemic state to `conflicted`. Neither claim is discarded or overwritten.
- Research syntheses are required to highlight conflicting evidence explicitly, providing researchers with both perspectives and their respective citations.

## Consequences
- The knowledge graph can represent mutually incompatible claims simultaneously without logical breakdown.
- User review workflows can inspect and tag conflicting evidence.
