import React, { useState, useEffect } from 'react';
import { 
  Settings, 
  ShieldAlert, 
  ShieldCheck, 
  Database, 
  Download, 
  Plus, 
  CheckCircle2, 
  AlertCircle, 
  Server, 
  RefreshCw 
} from 'lucide-react';
import { api } from '../api/client';
import { ConsentRecord } from '../types';

interface SettingsViewProps {
  workspaceId: string;
}

export const SettingsView: React.FC<SettingsViewProps> = ({ workspaceId }) => {
  const [consents, setConsents] = useState<ConsentRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);
  const [healthStatus, setHealthStatus] = useState<any>(null);

  // Grant modal state
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [provider, setProvider] = useState('openai');
  const [purpose, setPurpose] = useState('Research synthesis enrichment');
  const [scope, setScope] = useState('anonymized_claim_extracts');
  const [payloadPreview, setPayloadPreview] = useState('{"extracts": ["Sample claim 1", "Sample claim 2"]}');
  const [durationHours, setDurationHours] = useState(24);
  const [consentConfirmed, setConsentConfirmed] = useState(false);
  const [granting, setGranting] = useState(false);

  const loadData = async () => {
    try {
      setLoading(true);
      setError(null);
      const [consentData, health] = await Promise.all([
        api.listConsents(workspaceId).catch(() => []),
        api.getHealth().catch(() => null)
      ]);
      setConsents(consentData || []);
      setHealthStatus(health);
    } catch (err: any) {
      setError(err?.message || 'Failed to load settings data');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [workspaceId]);

  const handleRevokeConsent = async (consentId: string) => {
    if (!window.confirm('Are you sure you want to revoke this cloud transmission consent immediately?')) {
      return;
    }

    try {
      await api.revokeConsent(workspaceId, consentId);
      setSuccessMsg('Consent token successfully revoked.');
      setTimeout(() => setSuccessMsg(null), 4000);
      await loadData();
    } catch (err: any) {
      alert(`Revocation failed: ${err?.message || 'Unknown error'}`);
    }
  };

  const handleGrantConsent = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!consentConfirmed) {
      alert('You must explicitly confirm understanding that this permits external network transmission.');
      return;
    }

    try {
      setGranting(true);
      await api.grantConsent(workspaceId, {
        provider,
        purpose,
        scope,
        preview: payloadPreview,
        duration_hours: durationHours
      });
      setSuccessMsg(`Cloud consent granted for provider "${provider}" (${durationHours}h).`);
      setTimeout(() => setSuccessMsg(null), 4000);
      setIsModalOpen(false);
      setConsentConfirmed(false);
      await loadData();
    } catch (err: any) {
      alert(`Grant failed: ${err?.message || 'Unknown error'}`);
    } finally {
      setGranting(false);
    }
  };

  const handleExportWorkspace = async () => {
    try {
      const data = await api.exportWorkspace(workspaceId);
      const jsonBlob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(jsonBlob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `synapse-workspace-${workspaceId.slice(0, 8)}-${Date.now()}.json`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      setSuccessMsg('Workspace export JSON downloaded successfully.');
      setTimeout(() => setSuccessMsg(null), 4000);
    } catch (err: any) {
      alert(`Export failed: ${err?.message || 'Unknown error'}`);
    }
  };

  return (
    <div className="flex-1 flex flex-col h-full bg-[#0B0F19] text-gray-100 overflow-y-auto">
      {/* Header */}
      <div className="p-6 border-b border-[#1F2937] flex items-center justify-between bg-[#111827]">
        <div>
          <div className="flex items-center gap-2">
            <Settings className="w-5 h-5 text-blue-400" />
            <h1 className="text-xl font-bold text-white tracking-wide">Workspace Settings & Cloud Consent</h1>
          </div>
          <p className="text-xs text-gray-400 mt-1 font-mono">
            Granular privacy controls, local model engine settings, and database management.
          </p>
        </div>

        <button
          onClick={loadData}
          disabled={loading}
          className="flex items-center gap-2 px-3.5 py-1.5 bg-[#1F2937] hover:bg-gray-800 text-gray-300 rounded-lg text-xs font-medium border border-gray-700 transition"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
          <span>Refresh</span>
        </button>
      </div>

      {/* Notifications */}
      {successMsg && (
        <div className="px-6 py-2.5 bg-emerald-950/70 border-b border-emerald-800 text-emerald-300 text-xs flex items-center gap-2">
          <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" />
          <span>{successMsg}</span>
        </div>
      )}

      {error && (
        <div className="px-6 py-2.5 bg-red-950/70 border-b border-red-800 text-red-300 text-xs flex items-center gap-2">
          <AlertCircle className="w-4 h-4 text-red-400 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      <div className="p-6 space-y-6 max-w-5xl">
        {/* Section 1: Local-First & Zero Cloud Leakage */}
        <div className="bg-[#111827] border border-[#1F2937] rounded-xl p-5 shadow-sm">
          <div className="flex items-start justify-between pb-4 border-b border-gray-800">
            <div>
              <div className="flex items-center gap-2 text-white font-semibold text-sm">
                <ShieldCheck className="w-4 h-4 text-emerald-400" />
                <span>Zero Cloud Leakage & Privacy Boundary</span>
              </div>
              <p className="text-xs text-gray-400 mt-1">
                By default, Synapse operates strictly offline. All vector queries, graph traversals, and SQLite transactions remain inside loopback (127.0.0.1). Any outbound cloud API call requires an explicit, cryptographic user consent grant with fixed validity.
              </p>
            </div>
            
            <button
              onClick={() => setIsModalOpen(true)}
              className="flex items-center gap-1.5 px-3 py-1.5 bg-blue-600 hover:bg-blue-500 text-white rounded-lg text-xs font-medium transition shrink-0 ml-4 shadow-sm"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>Grant New Consent</span>
            </button>
          </div>

          {/* Active Consent Records Table */}
          <div className="mt-4">
            <h3 className="text-xs font-semibold text-gray-300 mb-2 uppercase tracking-wider font-mono">
              Cryptographic Consent Registry
            </h3>

            {consents.length === 0 ? (
              <div className="py-8 text-center text-gray-500 text-xs bg-[#0B0F19]/50 rounded-lg border border-gray-800">
                No cloud consent records active. Workspace is 100% locally isolated.
              </div>
            ) : (
              <div className="overflow-x-auto border border-gray-800 rounded-lg">
                <table className="w-full text-left text-xs">
                  <thead className="bg-[#0B0F19] text-gray-400 border-b border-gray-800 font-mono">
                    <tr>
                      <th className="p-3">Provider</th>
                      <th className="p-3">Purpose</th>
                      <th className="p-3">Scope</th>
                      <th className="p-3">Valid Until</th>
                      <th className="p-3">Status</th>
                      <th className="p-3 text-right">Action</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-800">
                    {consents.map((c) => {
                      const isExpired = new Date(c.valid_until).getTime() < Date.now();
                      const isActive = !c.revoked && !isExpired;

                      return (
                        <tr key={c.id} className="hover:bg-gray-800/40">
                          <td className="p-3 font-semibold text-white">{c.provider}</td>
                          <td className="p-3 text-gray-300">{c.purpose}</td>
                          <td className="p-3 text-gray-400 font-mono text-[11px]">{c.scope}</td>
                          <td className="p-3 text-gray-400 font-mono text-[11px]">{new Date(c.valid_until).toLocaleString()}</td>
                          <td className="p-3">
                            <span className={`px-2 py-0.5 rounded text-[10px] font-mono font-bold ${
                              isActive 
                                ? 'bg-emerald-950 text-emerald-400 border border-emerald-800' 
                                : c.revoked 
                                ? 'bg-red-950 text-red-400 border border-red-800'
                                : 'bg-gray-800 text-gray-400 border border-gray-700'
                            }`}>
                              {c.revoked ? 'REVOKED' : isExpired ? 'EXPIRED' : 'ACTIVE'}
                            </span>
                          </td>
                          <td className="p-3 text-right">
                            {isActive && (
                              <button
                                onClick={() => handleRevokeConsent(c.id)}
                                className="px-2.5 py-1 bg-red-950/60 hover:bg-red-900 text-red-300 border border-red-800/60 rounded text-xs transition"
                              >
                                Revoke
                              </button>
                            )}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>

        {/* Section 2: Engine Diagnostics & Infrastructure */}
        <div className="bg-[#111827] border border-[#1F2937] rounded-xl p-5 shadow-sm">
          <div className="flex items-center gap-2 text-white font-semibold text-sm pb-4 border-b border-gray-800">
            <Server className="w-4 h-4 text-blue-400" />
            <span>Local Engine & SQLite Diagnostics</span>
          </div>

          <div className="mt-4 grid grid-cols-2 md:grid-cols-4 gap-4 text-xs font-mono">
            <div className="bg-[#0B0F19] p-3 rounded-lg border border-gray-800">
              <span className="text-gray-500 block text-[10px]">API SERVER STATUS</span>
              <span className="text-emerald-400 font-bold text-sm mt-0.5 block">
                {healthStatus?.status === 'ok' ? 'HEALTHY' : 'OFFLINE'}
              </span>
            </div>

            <div className="bg-[#0B0F19] p-3 rounded-lg border border-gray-800">
              <span className="text-gray-500 block text-[10px]">BACKEND RUNTIME</span>
              <span className="text-white font-bold text-sm mt-0.5 block">
                {healthStatus?.engine || 'Julia 1.13.0'}
              </span>
            </div>

            <div className="bg-[#0B0F19] p-3 rounded-lg border border-gray-800">
              <span className="text-gray-500 block text-[10px]">STORAGE ENGINE</span>
              <span className="text-white font-bold text-sm mt-0.5 block">
                {healthStatus?.database || 'SQLite 3 WAL'}
              </span>
            </div>

            <div className="bg-[#0B0F19] p-3 rounded-lg border border-gray-800">
              <span className="text-gray-500 block text-[10px]">LOOPBACK BOUNDARY</span>
              <span className="text-cyan-400 font-bold text-sm mt-0.5 block">
                127.0.0.1:8765
              </span>
            </div>
          </div>
        </div>

        {/* Section 3: Workspace Data Export */}
        <div className="bg-[#111827] border border-[#1F2937] rounded-xl p-5 shadow-sm">
          <div className="flex items-start justify-between">
            <div>
              <div className="flex items-center gap-2 text-white font-semibold text-sm">
                <Database className="w-4 h-4 text-purple-400" />
                <span>Workspace Data Export & Portable Archive</span>
              </div>
              <p className="text-xs text-gray-400 mt-1 max-w-xl">
                Export the complete workspace dataset (sources, chunks, concepts, claims, relations, review decisions, and immutable audit logs) into a single verifiable JSON bundle.
              </p>
            </div>

            <button
              onClick={handleExportWorkspace}
              className="flex items-center gap-2 px-4 py-2 bg-[#1F2937] hover:bg-gray-800 text-white rounded-lg text-xs font-medium border border-gray-700 transition shrink-0 ml-4"
            >
              <Download className="w-4 h-4 text-purple-400" />
              <span>Export Workspace JSON</span>
            </button>
          </div>
        </div>
      </div>

      {/* Grant Consent Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div className="bg-[#111827] border border-gray-700 rounded-xl max-w-lg w-full p-6 shadow-2xl">
            <div className="flex items-center gap-2 text-amber-400 font-bold text-base mb-2">
              <ShieldAlert className="w-5 h-5 shrink-0" />
              <span>Grant Outbound Cloud Consent</span>
            </div>
            
            <p className="text-xs text-gray-400 mb-4 leading-relaxed">
              This action creates an explicit cryptographic consent record allowing Synapse to communicate with an external provider for the specified payload.
            </p>

            <form onSubmit={handleGrantConsent} className="space-y-4 text-xs">
              <div>
                <label className="block text-gray-300 font-medium mb-1">Provider</label>
                <select
                  value={provider}
                  onChange={(e) => setProvider(e.target.value)}
                  className="w-full bg-[#0B0F19] border border-gray-700 rounded p-2 text-white"
                >
                  <option value="openai">OpenAI (api.openai.com)</option>
                  <option value="anthropic">Anthropic (api.anthropic.com)</option>
                  <option value="custom">Custom Cloud Endpoint</option>
                </select>
              </div>

              <div>
                <label className="block text-gray-300 font-medium mb-1">Purpose</label>
                <input
                  type="text"
                  value={purpose}
                  onChange={(e) => setPurpose(e.target.value)}
                  required
                  className="w-full bg-[#0B0F19] border border-gray-700 rounded p-2 text-white"
                />
              </div>

              <div>
                <label className="block text-gray-300 font-medium mb-1">Scope</label>
                <input
                  type="text"
                  value={scope}
                  onChange={(e) => setScope(e.target.value)}
                  required
                  className="w-full bg-[#0B0F19] border border-gray-700 rounded p-2 text-white font-mono text-[11px]"
                />
              </div>

              <div>
                <label className="block text-gray-300 font-medium mb-1">Payload Sample / Preview</label>
                <textarea
                  value={payloadPreview}
                  onChange={(e) => setPayloadPreview(e.target.value)}
                  rows={3}
                  className="w-full bg-[#0B0F19] border border-gray-700 rounded p-2 text-white font-mono text-[11px]"
                />
              </div>

              <div>
                <label className="block text-gray-300 font-medium mb-1">Duration (Hours)</label>
                <input
                  type="number"
                  min={1}
                  max={720}
                  value={durationHours}
                  onChange={(e) => setDurationHours(parseInt(e.target.value) || 24)}
                  className="w-full bg-[#0B0F19] border border-gray-700 rounded p-2 text-white"
                />
              </div>

              <div className="pt-2">
                <label className="flex items-start gap-2 cursor-pointer bg-amber-950/30 border border-amber-800/40 p-3 rounded-lg">
                  <input
                    type="checkbox"
                    checked={consentConfirmed}
                    onChange={(e) => setConsentConfirmed(e.target.checked)}
                    className="mt-0.5 rounded border-gray-700 text-amber-500 focus:ring-0"
                  />
                  <span className="text-[11px] text-amber-200 leading-snug">
                    I explicitly authorize outbound network transmission of the scoped payload to <strong>{provider}</strong>. I understand Synapse will log an immutable audit event for this grant.
                  </span>
                </label>
              </div>

              <div className="flex items-center justify-end gap-3 pt-3 border-t border-gray-800">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2 bg-[#1F2937] hover:bg-gray-800 text-gray-300 rounded text-xs transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={granting || !consentConfirmed}
                  className="px-4 py-2 bg-amber-600 hover:bg-amber-500 disabled:opacity-50 text-white font-medium rounded text-xs transition"
                >
                  {granting ? 'Granting...' : 'Grant Consent'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
