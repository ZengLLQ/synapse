export type EpistemicState = 
  | 'source_grounded'
  | 'ai_inferred'
  | 'human_reviewed'
  | 'conflicted'
  | 'insufficient_evidence';

export interface Workspace {
  id: string;
  name: string;
  path: string;
  created_at: string;
  updated_at: string;
  archived: boolean;
}

export interface Source {
  id: string;
  workspace_id: string;
  title: string;
  format: 'markdown' | 'plaintext' | 'pdf';
  checksum: string;
  original_path: string;
  managed_path: string;
  created_at: string;
  updated_at: string;
}

export interface GraphNode {
  id: string;
  type: 'concept' | 'claim' | 'method' | 'study' | 'source' | 'synthesis';
  label: string;
  description: string;
  epistemic_state: EpistemicState;
  evidence_id?: string | null;
  metadata?: Record<string, any>;
}

export interface GraphEdge {
  id: string;
  source: string;
  source_type: string;
  target: string;
  target_type: string;
  relation_type: 'supports' | 'contradicts' | 'qualifies' | 'derived_from' | 'uses_method' | 'evaluated_on' | 'extends' | 'related_to';
  epistemic_state: EpistemicState;
  provenance_id?: string | null;
}

export interface GraphData {
  nodes: GraphNode[];
  edges: GraphEdge[];
}

export interface ResolvedCitation {
  raw_tag: string;
  source_id: string;
  evidence_id: string;
  source_title: string;
  locator: string;
  excerpt: string;
  is_valid: boolean;
  validation_error?: string | null;
}

export interface ConflictReport {
  topic: string;
  source_a_id: string;
  source_a_title: string;
  claim_a: string;
  citation_a: string;
  source_b_id: string;
  source_b_title: string;
  claim_b: string;
  citation_b: string;
  explanation: string;
}

export interface ResearchAnswer {
  question: string;
  answer: string;
  epistemic_state: EpistemicState;
  citations: ResolvedCitation[];
  conflicts: ConflictReport[];
  limitations: string;
  retrieval_trace: Array<{
    chunk_id: string;
    source_id: string;
    evidence_id: string;
    score: number;
    title: string;
  }>;
}

export interface ReviewItem {
  id: string;
  workspace_id: string;
  entity_type: string;
  entity_id: string;
  rationale: string;
  confidence: number;
  status: 'pending' | 'accepted' | 'rejected';
  created_at: string;
  reviewed_at?: string | null;
}

export interface AuditEvent {
  id: string;
  workspace_id: string;
  correlation_id: string;
  actor: string;
  target_id: string;
  target_type: string;
  event_type: string;
  before_state?: string | null;
  after_state?: string | null;
  reason: string;
  created_at: string;
}

export interface ConsentRecord {
  id: string;
  workspace_id: string;
  provider: string;
  purpose: string;
  scope: string;
  payload_preview: string;
  granted_at: string;
  valid_until: string;
  revoked: boolean;
}

export interface EvidenceRecord {
  id: string;
  source_version_id: string;
  page_number?: number | null;
  start_line: number;
  end_line: number;
  start_char: number;
  end_char: number;
  excerpt: string;
  created_at: string;
}

export interface JobRecord {
  id: string;
  workspace_id: string;
  job_type: string;
  input_fingerprint: string;
  pipeline_version: string;
  status: 'queued' | 'running' | 'retry_wait' | 'cancel_requested' | 'cancelled' | 'succeeded' | 'failed';
  progress: number;
  stage: string;
  attempts: number;
  error_message?: string | null;
  output_references?: string | null;
  created_at: string;
  updated_at: string;
}

