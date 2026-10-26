module Epistemic

# Core epistemic states for evidence-based knowledge representation
const SOURCE_GROUNDED = "source_grounded"          # Directly backed by locatable source text
const AI_INFERRED = "ai_inferred"                  # Proposed by AI; awaiting human review
const HUMAN_REVIEWED = "human_reviewed"            # Inspected and accepted by user
const CONFLICTED = "conflicted"                    # Contradicted by alternative evidence in the graph
const INSUFFICIENT_EVIDENCE = "insufficient_evidence" # Inadequate source support to confirm claim

const VALID_EPISTEMIC_STATES = Set([
    SOURCE_GROUNDED,
    AI_INFERRED,
    HUMAN_REVIEWED,
    CONFLICTED,
    INSUFFICIENT_EVIDENCE
])

function validate_epistemic_state(state::AbstractString)
    state in VALID_EPISTEMIC_STATES || throw(ArgumentError("Invalid epistemic state: $state. Must be one of $(collect(VALID_EPISTEMIC_STATES))"))
    return true
end

end # module Epistemic
