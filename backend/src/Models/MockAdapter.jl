module MockAdapter

using ..ModelAdapters: AbstractModelAdapter

struct DeterministicMockAdapter <: AbstractModelAdapter
    adapter_name::String
    model_version::String
end

function DeterministicMockAdapter()
    return DeterministicMockAdapter("deterministic_mock", "1.0.0")
end

struct ExtractedCandidate
    type::String # 'concept', 'claim', 'method', 'study'
    name::String
    detail::String
    original_wording::String
    confidence::Float64
end

struct ExtractedRelationCandidate
    source_name::String
    source_type::String
    target_name::String
    target_type::String
    relation_type::String
    confidence::Float64
end

function extract_entities_from_text(adapter::DeterministicMockAdapter, text::String)
    candidates = ExtractedCandidate[]
    sentences = split(text, r"(?<=[.!?])\s+")

    # Technical concepts dictionary & regex
    concept_patterns = [
        r"\b(Transformer|Self-Attention|Multi-Head Attention|Feed-Forward Network|Positional Encoding)\b"i,
        r"\b(Low-Rank Adaptation|LoRA|Rank Decomposition Matrix|Adapter Modules)\b"i,
        r"\b(Optimizer Zeta|AdamW|SGD|Momentum Optimizer|Stochastic Gradient Descent|Vision Transformer|ResNet-50)\b"i,
        r"\b(Supervised Fine-Tuning|Zero-Shot Learning|Few-Shot Prompting)\b"i,
        r"\b(Quantum Annealing|Superconducting Qubit|Transmon Qubit|Surface Code|Decoherence Time)\b"i
    ]

    method_patterns = [
        r"\b(Scaled Dot-Product Attention|Low-Rank Parameterization|Backpropagation through Time)\b"i,
        r"\b(Layer Normalization|Residual Connection|Greedy Decoding)\b"i
    ]

    seen_concepts = Set{String}()
    for cp in concept_patterns
        for m in eachmatch(cp, text)
            cname = uppercase(m.match[1:1]) * lowercase(m.match[2:end])
            if !(cname in seen_concepts)
                push!(seen_concepts, cname)
                push!(candidates, ExtractedCandidate("concept", cname, "Technical concept identified in source text.", m.match, 0.95))
            end
        end
    end

    seen_methods = Set{String}()
    for mp in method_patterns
        for m in eachmatch(mp, text)
            mname = m.match
            if !(mname in seen_methods)
                push!(seen_methods, mname)
                push!(candidates, ExtractedCandidate("method", mname, "Algorithmic method or technique.", m.match, 0.92))
            end
        end
    end

    # Extract claims from sentences containing assertion indicators
    claim_indicators = [
        "demonstrates", "achieves", "reduces", "improves", "outperforms",
        "yields", "shows", "fails to", "cannot surpass", "decreases", "diverges"
    ]

    for sent in sentences
        sent_clean = strip(sent)
        length(sent_clean) < 15 && continue
        
        has_indicator = any(ind -> occursin(Regex("\\b$ind\\b", "i"), sent_clean), claim_indicators)
        if has_indicator
            norm_claim = sent_clean
            push!(candidates, ExtractedCandidate("claim", "Claim: $(norm_claim[1:min(50, end)])...", norm_claim, sent_clean, 0.88))
        end
    end

    return candidates
end

function extract_relations_from_text(adapter::DeterministicMockAdapter, text::String, entities::Vector{ExtractedCandidate})
    relations = ExtractedRelationCandidate[]
    
    concepts = filter(e -> e.type == "concept", entities)
    methods = filter(e -> e.type == "method", entities)
    claims = filter(e -> e.type == "claim", entities)

    # Link concepts to methods (derived_from / uses_method)
    for c in concepts
        for m in methods
            if occursin(lowercase(c.name), lowercase(m.name)) || occursin(lowercase(m.name), lowercase(c.name))
                push!(relations, ExtractedRelationCandidate(c.name, "concept", m.name, "method", "uses_method", 0.90))
            end
        end
    end

    # Link claims to concepts (related_to / supports)
    for cl in claims
        for c in concepts
            if occursin(lowercase(c.name), lowercase(cl.original_wording))
                push!(relations, ExtractedRelationCandidate(c.name, "concept", cl.name, "claim", "supports", 0.85))
            end
        end
    end

    # Detect empirical contradiction between conflicting claims
    for i in 1:length(claims)
        for j in (i+1):length(claims)
            c1 = claims[i]
            c2 = claims[j]
            is_c1_pos = any(p -> occursin(Regex("\\b$p\\b", "i"), c1.original_wording), ["achieves", "improves", "outperforms", "dominance", "stable"])
            is_c2_neg = any(p -> occursin(Regex("\\b$p\\b", "i"), c2.original_wording), ["fails to", "cannot", "divergence", "catastrophic", "diverges"])
            
            is_c2_pos = any(p -> occursin(Regex("\\b$p\\b", "i"), c2.original_wording), ["achieves", "improves", "outperforms", "dominance", "stable"])
            is_c1_neg = any(p -> occursin(Regex("\\b$p\\b", "i"), c1.original_wording), ["fails to", "cannot", "divergence", "catastrophic", "diverges"])

            if (is_c1_pos && is_c2_neg) || (is_c2_pos && is_c1_neg)
                push!(relations, ExtractedRelationCandidate(c1.name, "claim", c2.name, "claim", "contradicts", 0.94))
            end
        end
    end

    return relations
end

end # module MockAdapter
