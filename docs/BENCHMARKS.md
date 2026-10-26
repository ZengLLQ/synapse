# Synapse Evaluation & Benchmarks

## 1. Quality Target Baselines

| Metric | Target | Measurement Methodology |
|---|---|---|
| **Citation Validity** | 100% | Every citation in a synthesized answer must resolve to an existing source record, valid source version, and non-empty text locator span in the database. |
| **Retrieval Precision@5** | ≥ 0.80 | Evaluated on human-labeled query-document pairs in `benchmarks/fixtures/`. A document chunk is relevant if it contains the ground-truth answer snippet. |
| **Entity Extraction F1** | ≥ 0.85 | Precision and recall on annotated technical concepts, claims, methods, and studies in the benchmark corpus. |
| **Relation Extraction F1** | ≥ 0.75 | Validated across relation types (`supports`, `contradicts`, `qualifies`, `derived_from`, `uses_method`, `evaluated_on`, `extends`, `related_to`). |
| **Audit Event Coverage** | 100% | Every graph node creation, edge link, status change, and review action must emit a corresponding `AuditEvent` in SQLite within the same transaction. |
| **Zero Cloud Leakage** | 100% Blocked | All outgoing model requests without an active, matching `ConsentRecord` must be blocked by the `CloudConsentGuard`. |
| **Contradiction Preservation** | 100% Preserved | When two sources make incompatible empirical claims, neither claim is overwritten. A `contradicts` relation is generated and the claim epistemic state is set to `conflicted`. |

## 2. Benchmark Corpus

The benchmark corpus consists of:
1. `attention_is_all_you_need.md`: Standard transformer architecture specification.
2. `lora_low_rank_adaptation.md`: Parameter-efficient fine-tuning methodology.
3. `conflicting_optimizer_benchmark.md`: Synthetic paper asserting optimizer results directly contradictory to established baseline benchmarks to stress contradiction handling.
4. `synthetic_quantum_memo.txt`: Plain text benchmark document testing offset locators and plain text chunking.
5. `scanned_sample_notice.pdf`: A test PDF to verify OCR requirement detection and safe failure behavior.

## 3. Running Benchmarks

```bash
cd backend
julia --project=. benchmarks/run_benchmarks.jl
```
The script runs all benchmark suites, verifies acceptance criteria, prints a detailed report, and outputs summary metrics.
