import { 
  Workspace, Source, GraphData, ResearchAnswer, 
  ReviewItem, AuditEvent, ConsentRecord, EvidenceRecord, JobRecord
} from '../types';

class SynapseApiClient {
  private baseUrl: string;
  private token: string;

  constructor() {
    this.baseUrl = import.meta.env.VITE_SYNAPSE_API_URL || 'http://127.0.0.1:8765/api/v1';
    this.token = import.meta.env.VITE_SYNAPSE_TOKEN || 'local_desktop_session_token';
  }

  setToken(token: string) {
    this.token = token;
  }

  setBaseUrl(url: string) {
    this.baseUrl = url;
  }

  private async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const headers = {
      'Content-Type': 'application/json',
      'X-Synapse-Token': this.token,
      ...(options.headers || {})
    };

    const res = await fetch(`${this.baseUrl}${endpoint}`, {
      ...options,
      headers
    });

    if (!res.ok) {
      let errData;
      try {
        errData = await res.json();
      } catch {
        throw new Error(`HTTP Error ${res.status}: ${res.statusText}`);
      }
      throw new Error(errData?.error?.message || `HTTP ${res.status}`);
    }

    const json = await res.json();
    return json.data;
  }

  // Health
  async getHealth() {
    return this.request<{ status: string; uptime: number }>('/health');
  }

  // Workspaces
  async listWorkspaces() {
    return this.request<Workspace[]>('/workspaces');
  }

  async createWorkspace(name: string, path: string) {
    return this.request<Workspace>('/workspaces', {
      method: 'POST',
      body: JSON.stringify({ name, path })
    });
  }

  async getWorkspace(id: string) {
    return this.request<Workspace>(`/workspaces/${id}`);
  }

  async renameWorkspace(id: string, name: string) {
    return this.request<Workspace>(`/workspaces/${id}/rename`, {
      method: 'POST',
      body: JSON.stringify({ name })
    });
  }

  async archiveWorkspace(id: string) {
    return this.request<{ archived: boolean; workspace_id: string }>(`/workspaces/${id}/archive`, {
      method: 'POST'
    });
  }

  // Sources
  async listSources(workspaceId: string) {
    return this.request<Source[]>(`/workspaces/${workspaceId}/sources`);
  }

  async importSource(workspaceId: string, filePath: string, title?: string) {
    return this.request<{ source: Source; is_duplicate: boolean; chunks_count: number }>(`/workspaces/${workspaceId}/sources/import`, {
      method: 'POST',
      body: JSON.stringify({ file_path: filePath, title })
    });
  }

  async getSource(workspaceId: string, sourceId: string) {
    return this.request<Source>(`/workspaces/${workspaceId}/sources/${sourceId}`);
  }

  async getSourceContent(workspaceId: string, sourceId: string) {
    return this.request<{ source: Source; content: string }>(`/workspaces/${workspaceId}/sources/${sourceId}/content`);
  }

  async getSourceEvidence(workspaceId: string, sourceId: string) {
    return this.request<EvidenceRecord[]>(`/workspaces/${workspaceId}/sources/${sourceId}/evidence`);
  }

  // Graph
  async getGraph(workspaceId: string, limit: number = 200) {
    return this.request<GraphData>(`/workspaces/${workspaceId}/graph?limit=${limit}`);
  }

  async getNeighborhood(workspaceId: string, nodeId: string) {
    return this.request<GraphData>(`/workspaces/${workspaceId}/graph/neighborhood/${nodeId}`);
  }

  // Research Assistant
  async askQuestion(workspaceId: string, question: string, limit: number = 5) {
    return this.request<ResearchAnswer>(`/workspaces/${workspaceId}/research/ask`, {
      method: 'POST',
      body: JSON.stringify({ question, limit })
    });
  }

  async saveSynthesis(workspaceId: string, payload: { question: string; answer: string; limitations: string; citations: any[] }) {
    return this.request<any>(`/workspaces/${workspaceId}/research/synthesize`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  // Review Queue
  async listReviewQueue(workspaceId: string, status: string = 'pending') {
    return this.request<ReviewItem[]>(`/workspaces/${workspaceId}/review?status=${status}`);
  }

  async decideReviewItem(workspaceId: string, reviewId: string, action: 'accept' | 'reject', notes: string) {
    return this.request<{ success: boolean }>(`/workspaces/${workspaceId}/review/${reviewId}/decide`, {
      method: 'POST',
      body: JSON.stringify({ action, notes })
    });
  }

  // Audit
  async listAuditEvents(workspaceId: string, limit: number = 50, offset: number = 0) {
    return this.request<AuditEvent[]>(`/workspaces/${workspaceId}/audit?limit=${limit}&offset=${offset}`);
  }

  async undoMutation(workspaceId: string, auditEventId: string) {
    return this.request<{ success: boolean }>(`/workspaces/${workspaceId}/audit/undo`, {
      method: 'POST',
      body: JSON.stringify({ audit_event_id: auditEventId })
    });
  }

  // Jobs
  async listJobs(workspaceId: string) {
    return this.request<JobRecord[]>(`/workspaces/${workspaceId}/jobs`);
  }

  async getJob(workspaceId: string, jobId: string) {
    return this.request<JobRecord>(`/workspaces/${workspaceId}/jobs/${jobId}`);
  }

  async retryJob(workspaceId: string, jobId: string) {
    return this.request<JobRecord>(`/workspaces/${workspaceId}/jobs/${jobId}/retry`, {
      method: 'POST'
    });
  }

  async cancelJob(workspaceId: string, jobId: string) {
    return this.request<{ cancelled: boolean; job_id: string }>(`/workspaces/${workspaceId}/jobs/${jobId}/cancel`, {
      method: 'POST'
    });
  }

  // Consents
  async listConsents(workspaceId: string) {
    return this.request<ConsentRecord[]>(`/workspaces/${workspaceId}/consents`);
  }

  async grantConsent(workspaceId: string, payload: { provider: string; purpose: string; scope: string; preview: string; duration_hours?: number }) {
    return this.request<{ consent_id: string }>(`/workspaces/${workspaceId}/consents/grant`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  async revokeConsent(workspaceId: string, consentId: string) {
    return this.request<{ success: boolean }>(`/workspaces/${workspaceId}/consents/revoke`, {
      method: 'POST',
      body: JSON.stringify({ consent_id: consentId })
    });
  }

  // Export
  async exportWorkspace(workspaceId: string) {
    return this.request<any>(`/workspaces/${workspaceId}/export`);
  }
}

export const api = new SynapseApiClient();

