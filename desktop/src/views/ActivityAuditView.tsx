import React, { useState, useEffect } from 'react';
import { 
  History, 
  RotateCcw, 
  Search, 
  Filter, 
  ChevronDown, 
  ChevronRight, 
  User, 
  Bot, 
  Cpu, 
  CheckCircle2, 
  AlertCircle,
  FileCode,
  ShieldCheck,
  RefreshCw,
  ListTodo,
  StopCircle
} from 'lucide-react';
import { api } from '../api/client';
import { AuditEvent, JobRecord } from '../types';

interface ActivityAuditViewProps {
  workspaceId: string;
}

export const ActivityAuditView: React.FC<ActivityAuditViewProps> = ({ workspaceId }) => {
  const [activeTab, setActiveTab] = useState<'audit' | 'jobs'>('audit');
  const [events, setEvents] = useState<AuditEvent[]>([]);
  const [jobs, setJobs] = useState<JobRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [actorFilter, setActorFilter] = useState<string>('all');
  const [expandedDiffs, setExpandedDiffs] = useState<Record<string, boolean>>({});
  const [undoingId, setUndoingId] = useState<string | null>(null);
  const [undoSuccess, setUndoSuccess] = useState<string | null>(null);
  const [retryingJobId, setRetryingJobId] = useState<string | null>(null);

  const loadData = async () => {
    try {
      setLoading(true);
      setError(null);
      const [auditData, jobsData] = await Promise.all([
        api.listAuditEvents(workspaceId, 100).catch(() => []),
        api.listJobs(workspaceId).catch(() => [])
      ]);
      setEvents(auditData || []);
      setJobs(jobsData || []);
    } catch (err: any) {
      setError(err?.message || 'Failed to load audit events and jobs');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [workspaceId]);

  const handleRetryJob = async (jobId: string) => {
    setRetryingJobId(jobId);
    try {
      await api.retryJob(workspaceId, jobId);
      setUndoSuccess(`Job ${jobId.slice(0, 8)} successfully retried and queued.`);
      setTimeout(() => setUndoSuccess(null), 4000);
      await loadData();
    } catch (err: any) {
      alert(`Retry failed: ${err?.message || 'Unknown error'}`);
    } finally {
      setRetryingJobId(null);
    }
  };

  const handleCancelJob = async (jobId: string) => {
    try {
      await api.cancelJob(workspaceId, jobId);
      setUndoSuccess(`Cancellation requested for job ${jobId.slice(0, 8)}.`);
      setTimeout(() => setUndoSuccess(null), 4000);
      await loadData();
    } catch (err: any) {
      alert(`Cancel failed: ${err?.message || 'Unknown error'}`);
    }
  };

  const toggleDiff = (id: string) => {
    setExpandedDiffs(prev => ({ ...prev, [id]: !prev[id] }));
  };

  const handleUndo = async (eventId: string) => {
    if (!window.confirm('Are you sure you want to revert this mutation? This will record a compensating audit event.')) {
      return;
    }

    try {
      setUndoingId(eventId);
      await api.undoMutation(workspaceId, eventId);
      setUndoSuccess(`Successfully reverted mutation from event #${eventId.slice(0, 8)}`);
      setTimeout(() => setUndoSuccess(null), 4000);
      await loadData();
    } catch (err: any) {
      alert(`Undo failed: ${err?.message || 'Unknown error'}`);
    } finally {
      setUndoingId(null);
    }
  };

  const getActorIcon = (actor: string) => {
    const act = actor.toLowerCase();
    if (act.includes('human') || act.includes('user')) {
      return <User className="w-3.5 h-3.5 text-blue-400" />;
    } else if (act.includes('agent') || act.includes('ai') || act.includes('pipeline')) {
      return <Bot className="w-3.5 h-3.5 text-purple-400" />;
    }
    return <Cpu className="w-3.5 h-3.5 text-emerald-400" />;
  };

  const getActorBadgeClass = (actor: string) => {
    const act = actor.toLowerCase();
    if (act.includes('human') || act.includes('user')) {
      return 'bg-blue-900/40 text-blue-300 border-blue-700/50';
    } else if (act.includes('agent') || act.includes('ai') || act.includes('pipeline')) {
      return 'bg-purple-900/40 text-purple-300 border-purple-700/50';
    }
    return 'bg-emerald-900/40 text-emerald-300 border-emerald-700/50';
  };

  const getEventTypeBadgeClass = (eventType: string) => {
    const type = eventType.toLowerCase();
    if (type.includes('create') || type.includes('insert') || type.includes('import')) {
      return 'bg-emerald-950/60 text-emerald-400 border-emerald-800/60';
    } else if (type.includes('update') || type.includes('modify')) {
      return 'bg-amber-950/60 text-amber-400 border-amber-800/60';
    } else if (type.includes('delete') || type.includes('remove')) {
      return 'bg-red-950/60 text-red-400 border-red-800/60';
    } else if (type.includes('undo') || type.includes('revert')) {
      return 'bg-cyan-950/60 text-cyan-400 border-cyan-800/60';
    }
    return 'bg-gray-800 text-gray-300 border-gray-700';
  };

  const isUndoable = (event: AuditEvent) => {
    const type = event.event_type.toLowerCase();
    return (type.includes('create') || type.includes('update') || type.includes('delete')) && 
           !type.includes('undo') &&
           Boolean(event.before_state || event.after_state);
  };

  const getJobStatusBadge = (status: string) => {
    switch (status.toLowerCase()) {
      case 'succeeded':
        return 'bg-emerald-950/60 text-emerald-400 border-emerald-800/60';
      case 'running':
        return 'bg-blue-950/60 text-blue-400 border-blue-800/60 animate-pulse';
      case 'queued':
      case 'retry_wait':
        return 'bg-amber-950/60 text-amber-400 border-amber-800/60';
      case 'failed':
        return 'bg-red-950/60 text-red-400 border-red-800/60';
      case 'cancelled':
      case 'cancel_requested':
        return 'bg-gray-800 text-gray-400 border-gray-700';
      default:
        return 'bg-gray-800 text-gray-300 border-gray-700';
    }
  };

  const filteredEvents = events.filter(e => {
    const matchesActor = actorFilter === 'all' || 
      (actorFilter === 'human' && (e.actor.includes('human') || e.actor.includes('user'))) ||
      (actorFilter === 'agent' && (e.actor.includes('agent') || e.actor.includes('ai') || e.actor.includes('pipeline'))) ||
      (actorFilter === 'system' && e.actor.includes('system'));

    const q = searchQuery.toLowerCase();
    const matchesQuery = !searchQuery || 
      e.target_id.toLowerCase().includes(q) ||
      e.target_type.toLowerCase().includes(q) ||
      e.event_type.toLowerCase().includes(q) ||
      e.reason.toLowerCase().includes(q) ||
      e.actor.toLowerCase().includes(q);

    return matchesActor && matchesQuery;
  });

  const formatJson = (str?: string | null) => {
    if (!str) return 'None';
    try {
      const parsed = JSON.parse(str);
      return JSON.stringify(parsed, null, 2);
    } catch {
      return str;
    }
  };

  return (
    <div className="flex-1 flex flex-col h-full bg-[#0B0F19] text-gray-100 overflow-hidden">
      {/* Header */}
      <div className="p-6 border-b border-[#1F2937] flex items-center justify-between bg-[#111827]">
        <div>
          <div className="flex items-center gap-2">
            <History className="w-5 h-5 text-blue-400" />
            <h1 className="text-xl font-bold text-white tracking-wide">Activity & Background Pipeline</h1>
          </div>
          <p className="text-xs text-gray-400 mt-1 flex items-center gap-1.5 font-mono">
            <ShieldCheck className="w-3.5 h-3.5 text-emerald-400" />
            Tamper-evident audit log & background job orchestrator with bounded retries.
          </p>
        </div>

        <div className="flex items-center gap-3">
          {/* Tab switcher */}
          <div className="flex bg-[#0B0F19] p-1 rounded-lg border border-[#1F2937]">
            <button
              onClick={() => setActiveTab('audit')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-medium transition ${
                activeTab === 'audit'
                  ? 'bg-blue-600 text-white shadow-sm'
                  : 'text-gray-400 hover:text-white'
              }`}
            >
              <History className="w-3.5 h-3.5" />
              <span>Audit Log ({events.length})</span>
            </button>
            <button
              onClick={() => setActiveTab('jobs')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-medium transition ${
                activeTab === 'jobs'
                  ? 'bg-blue-600 text-white shadow-sm'
                  : 'text-gray-400 hover:text-white'
              }`}
            >
              <ListTodo className="w-3.5 h-3.5" />
              <span>Jobs & Pipeline ({jobs.length})</span>
            </button>
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
      </div>

      {/* Notifications */}
      {undoSuccess && (
        <div className="px-6 py-2.5 bg-emerald-950/70 border-b border-emerald-800 text-emerald-300 text-xs flex items-center gap-2">
          <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" />
          <span>{undoSuccess}</span>
        </div>
      )}

      {error && (
        <div className="px-6 py-2.5 bg-red-950/70 border-b border-red-800 text-red-300 text-xs flex items-center gap-2">
          <AlertCircle className="w-4 h-4 text-red-400 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {activeTab === 'audit' ? (
        <>
          {/* Filter / Search Bar */}
          <div className="p-4 border-b border-[#1F2937] flex items-center justify-between gap-4 bg-[#0B0F19]">
            <div className="relative flex-1 max-w-md">
              <Search className="w-4 h-4 text-gray-500 absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                placeholder="Search events by actor, entity type, ID, or reason..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full pl-9 pr-3 py-1.5 bg-[#111827] border border-[#1F2937] rounded-lg text-xs text-white placeholder-gray-500 focus:outline-none focus:border-blue-500"
              />
            </div>

            {/* Actor filter buttons */}
            <div className="flex items-center gap-1.5 bg-[#111827] p-1 border border-[#1F2937] rounded-lg text-xs">
              <Filter className="w-3.5 h-3.5 text-gray-400 ml-2 mr-1" />
              {(['all', 'human', 'agent', 'system'] as const).map(f => (
                <button
                  key={f}
                  onClick={() => setActorFilter(f)}
                  className={`px-2.5 py-1 rounded capitalize transition font-medium ${
                    actorFilter === f 
                      ? 'bg-blue-600 text-white' 
                      : 'text-gray-400 hover:text-gray-200'
                  }`}
                >
                  {f}
                </button>
              ))}
            </div>
          </div>

          {/* Events List */}
          <div className="flex-1 overflow-y-auto p-6 space-y-3">
            {loading && events.length === 0 ? (
              <div className="flex flex-col items-center justify-center h-64 text-gray-500 gap-3">
                <RefreshCw className="w-6 h-6 animate-spin text-blue-500" />
                <p className="text-sm">Loading audit timeline...</p>
              </div>
            ) : filteredEvents.length === 0 ? (
              <div className="text-center py-16 text-gray-500 text-sm">
                No audit events found matching your filter criteria.
              </div>
            ) : (
              filteredEvents.map((event) => {
                const isExpanded = !!expandedDiffs[event.id];
                const hasDiff = Boolean(event.before_state || event.after_state);
                const canUndo = isUndoable(event);

                return (
                  <div 
                    key={event.id}
                    className="bg-[#111827] border border-[#1F2937] hover:border-gray-700/80 rounded-xl p-4 transition-all shadow-sm"
                  >
                    <div className="flex items-start justify-between gap-4">
                      <div className="flex items-start gap-3">
                        {/* Timestamp & Actor */}
                        <div className="mt-0.5">
                          <div className={`px-2 py-0.5 rounded border text-[11px] font-mono flex items-center gap-1.5 ${getActorBadgeClass(event.actor)}`}>
                            {getActorIcon(event.actor)}
                            <span>{event.actor}</span>
                          </div>
                        </div>

                        <div>
                          <div className="flex items-center gap-2 flex-wrap">
                            <span className={`px-2 py-0.5 rounded border text-xs font-semibold ${getEventTypeBadgeClass(event.event_type)}`}>
                              {event.event_type}
                            </span>

                            <span className="text-xs text-gray-400 font-mono">
                              Target: <strong className="text-gray-200">{event.target_type}</strong> ({event.target_id.slice(0, 12)}...)
                            </span>

                            <span className="text-[11px] text-gray-500 font-mono">
                              {new Date(event.created_at).toLocaleString()}
                            </span>
                          </div>

                          <p className="text-xs text-gray-300 mt-1.5 leading-relaxed">
                            {event.reason || 'No explicit reason provided.'}
                          </p>
                        </div>
                      </div>

                      {/* Actions: Undo & View Diff */}
                      <div className="flex items-center gap-2 shrink-0">
                        {canUndo && (
                          <button
                            onClick={() => handleUndo(event.id)}
                            disabled={undoingId === event.id}
                            className="flex items-center gap-1.5 px-2.5 py-1 bg-amber-950/40 hover:bg-amber-900/60 text-amber-300 border border-amber-800/60 rounded text-xs transition disabled:opacity-50"
                            title="Revert mutation and append compensating audit record"
                          >
                            <RotateCcw className={`w-3.5 h-3.5 ${undoingId === event.id ? 'animate-spin' : ''}`} />
                            <span>Undo Mutation</span>
                          </button>
                        )}

                        {hasDiff && (
                          <button
                            onClick={() => toggleDiff(event.id)}
                            className="flex items-center gap-1 px-2.5 py-1 bg-[#1F2937] hover:bg-gray-800 text-gray-300 border border-gray-700 rounded text-xs transition"
                          >
                            <FileCode className="w-3.5 h-3.5 text-blue-400" />
                            <span>{isExpanded ? 'Hide Diff' : 'View Diff'}</span>
                            {isExpanded ? <ChevronDown className="w-3.5 h-3.5" /> : <ChevronRight className="w-3.5 h-3.5" />}
                          </button>
                        )}
                      </div>
                    </div>

                    {/* Diff Viewer */}
                    {isExpanded && hasDiff && (
                      <div className="mt-4 pt-3 border-t border-gray-800 grid grid-cols-2 gap-3 text-xs font-mono">
                        <div className="bg-[#0B0F19] p-3 rounded-lg border border-red-900/30 overflow-x-auto">
                          <div className="text-red-400 font-semibold mb-1 text-[11px] uppercase tracking-wider">
                            Before State
                          </div>
                          <pre className="text-gray-400 whitespace-pre-wrap leading-relaxed text-[11px]">
                            {formatJson(event.before_state)}
                          </pre>
                        </div>

                        <div className="bg-[#0B0F19] p-3 rounded-lg border border-emerald-900/30 overflow-x-auto">
                          <div className="text-emerald-400 font-semibold mb-1 text-[11px] uppercase tracking-wider">
                            After State
                          </div>
                          <pre className="text-gray-300 whitespace-pre-wrap leading-relaxed text-[11px]">
                            {formatJson(event.after_state)}
                          </pre>
                        </div>
                      </div>
                    )}
                  </div>
                );
              })
            )}
          </div>
        </>
      ) : (
        /* Jobs & Pipeline Tab */
        <div className="flex-1 overflow-y-auto p-6 space-y-4">
          <div className="grid grid-cols-4 gap-3 mb-2">
            <div className="bg-[#111827] border border-[#1F2937] p-3.5 rounded-xl">
              <div className="text-xs text-gray-400 font-medium">Total Jobs</div>
              <div className="text-xl font-bold text-white mt-1">{jobs.length}</div>
            </div>
            <div className="bg-[#111827] border border-[#1F2937] p-3.5 rounded-xl">
              <div className="text-xs text-blue-400 font-medium">Running</div>
              <div className="text-xl font-bold text-blue-300 mt-1">
                {jobs.filter(j => j.status === 'running').length}
              </div>
            </div>
            <div className="bg-[#111827] border border-[#1F2937] p-3.5 rounded-xl">
              <div className="text-xs text-amber-400 font-medium">Queued</div>
              <div className="text-xl font-bold text-amber-300 mt-1">
                {jobs.filter(j => j.status === 'queued' || j.status === 'retry_wait').length}
              </div>
            </div>
            <div className="bg-[#111827] border border-[#1F2937] p-3.5 rounded-xl">
              <div className="text-xs text-red-400 font-medium">Failed</div>
              <div className="text-xl font-bold text-red-300 mt-1">
                {jobs.filter(j => j.status === 'failed').length}
              </div>
            </div>
          </div>

          {loading && jobs.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-64 text-gray-500 gap-3">
              <RefreshCw className="w-6 h-6 animate-spin text-blue-500" />
              <p className="text-sm">Loading background jobs...</p>
            </div>
          ) : jobs.length === 0 ? (
            <div className="text-center py-16 bg-[#111827] border border-[#1F2937] rounded-xl text-gray-500 text-sm">
              <ListTodo className="w-8 h-8 text-gray-600 mx-auto mb-2" />
              No background jobs found in this workspace.
            </div>
          ) : (
            jobs.map((job) => {
              const progressPct = Math.min(100, Math.max(0, Math.round((job.progress || 0) * 100)));
              const canRetry = job.status === 'failed' || job.status === 'cancelled';
              const canCancel = job.status === 'queued' || job.status === 'running' || job.status === 'retry_wait';

              return (
                <div
                  key={job.id}
                  className="bg-[#111827] border border-[#1F2937] hover:border-gray-700/80 rounded-xl p-4 transition-all shadow-sm"
                >
                  <div className="flex items-start justify-between gap-4">
                    <div className="space-y-1.5 flex-1">
                      <div className="flex items-center gap-2.5 flex-wrap">
                        <span className={`px-2.5 py-0.5 rounded-full border text-xs font-semibold capitalize ${getJobStatusBadge(job.status)}`}>
                          {job.status}
                        </span>

                        <span className="text-sm font-semibold text-white font-mono">
                          {job.job_type}
                        </span>

                        <span className="text-xs text-gray-400 font-mono">
                          ID: {job.id.slice(0, 10)}...
                        </span>

                        <span className="text-[11px] text-gray-500 font-mono">
                          Stage: {job.stage}
                        </span>

                        <span className="text-[11px] text-gray-500 font-mono">
                          Attempts: {job.attempts}
                        </span>
                      </div>

                      {/* Progress Bar */}
                      <div className="mt-3">
                        <div className="flex justify-between text-xs text-gray-400 mb-1 font-mono">
                          <span>Progress</span>
                          <span>{progressPct}%</span>
                        </div>
                        <div className="w-full bg-gray-800 rounded-full h-2 overflow-hidden border border-gray-700/50">
                          <div 
                            className={`h-full transition-all duration-300 ${
                              job.status === 'succeeded'
                                ? 'bg-emerald-500'
                                : job.status === 'failed'
                                ? 'bg-red-500'
                                : 'bg-blue-500'
                            }`}
                            style={{ width: `${progressPct}%` }}
                          />
                        </div>
                      </div>

                      {/* Error display */}
                      {job.error_message && (
                        <div className="mt-2.5 p-2.5 bg-red-950/40 border border-red-800/60 rounded-lg text-xs text-red-300 font-mono">
                          <strong>Failure reason:</strong> {job.error_message}
                        </div>
                      )}

                      {/* Timestamps */}
                      <div className="pt-2 text-[11px] text-gray-500 flex items-center gap-4 font-mono">
                        <span>Created: {new Date(job.created_at).toLocaleString()}</span>
                        <span>Updated: {new Date(job.updated_at).toLocaleString()}</span>
                      </div>
                    </div>

                    {/* Actions */}
                    <div className="flex items-center gap-2 shrink-0">
                      {canRetry && (
                        <button
                          onClick={() => handleRetryJob(job.id)}
                          disabled={retryingJobId === job.id}
                          className="flex items-center gap-1.5 px-3 py-1.5 bg-blue-600 hover:bg-blue-500 text-white rounded-lg text-xs font-medium transition disabled:opacity-50"
                        >
                          <RefreshCw className={`w-3.5 h-3.5 ${retryingJobId === job.id ? 'animate-spin' : ''}`} />
                          <span>Retry Job</span>
                        </button>
                      )}

                      {canCancel && (
                        <button
                          onClick={() => handleCancelJob(job.id)}
                          className="flex items-center gap-1.5 px-3 py-1.5 bg-red-950/60 hover:bg-red-900/80 text-red-300 border border-red-800/60 rounded-lg text-xs font-medium transition"
                        >
                          <StopCircle className="w-3.5 h-3.5" />
                          <span>Cancel</span>
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              );
            })
          )}
        </div>
      )}
    </div>
  );
};
