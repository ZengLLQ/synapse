# ADR 0001: Julia as Primary Language in a Modular Monolith

## Status
Accepted

## Context
Synapse requires rich domain modeling, graph operations, text processing, mathematical/scientific primitives, and local research synthesis. We evaluated splitting the engine into microservices (Python for ML, Go/Rust for API, Julia for math) versus a unified modular monolith.

## Decision
We chose **Julia** as the single primary programming language for the backend, organized as a modular monolith under `backend/src/`.

## Rationale
- Multiple microservices introduce network latency, inter-process failure modes, serialization overhead, and deployment complexity that harm a local desktop application.
- Julia provides expressiveness comparable to Python, execution speeds comparable to C/Rust, and a strong parametric type system well-suited for representing epistemic states and knowledge graphs.
- Clear module boundaries (`Synapse.Workspace`, `Synapse.Ingestion`, `Synapse.Domain`, `Synapse.Graph`, etc.) ensure maintainability without the operational burden of microservices.

## Consequences
- The desktop shell must manage the lifecycle of the Julia process.
- All domain rules reside authoritatively in Julia; the frontend never reimplements domain validation.
