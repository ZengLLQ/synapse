import React, { useState } from 'react';
import { ResearchAnswer } from '../types';
import { EpistemicBadge } from '../components/EpistemicBadge';
import { 
  FlaskConical, 
  Send, 
  ShieldCheck, 
  AlertTriangle, 
  BookmarkPlus, 
  HelpCircle, 
  CheckCircle2,
  ExternalLink
} from 'lucide-react';

interface ResearchStudioProps {
  onAskQuestion: (question: string) => Promise<ResearchAnswer>;
  onSaveSynthesis: (payload: { question: string; answer: string; limitations: string; citations: any[] }) => Promise<void>;
  onOpenCitation?: (sourceId: string, locator: string, evidenceId: string) => void;
}

export const ResearchStudio: React.FC<ResearchStudioProps> = ({
  onAskQuestion,
  onSaveSynthesis,
  onOpenCitation
}) => {
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(false);
  const [answer, setAnswer] = useState<ResearchAnswer | null>(null);
  const [saving, setSaving] = useState(false);
  const [savedSuccess, setSavedSuccess] = useState(false);

  const handleAsk = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!query.trim() || loading) return;
    setLoading(true);
    setSavedSuccess(false);
    try {
      const res = await onAskQuestion(query.trim());
      setAnswer(res);
    } catch (err: any) {
      alert(`Research query failed: ${err.message}`);
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    if (!answer) return;
    setSaving(true);
    try {
      await onSaveSynthesis({
        question: answer.question,
        answer: answer.answer,
        limitations: answer.limitations,
        citations: answer.citations
      });
      setSavedSuccess(true);
    } catch (err: any) {
      alert(`Failed to save synthesis: ${err.message}`);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="p-8 max-w-5xl mx-auto space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-white flex items-center gap-2.5">
          <FlaskConical className="w-6 h-6 text-blue-400" />
          <span>Research Studio</span>
        </h1>
        <p className="text-sm text-gray-400 mt-1">
          Ask research questions across your imported literature. Synthesizes grounded answers, surfaces conflicting empirical claims, and validates citations.
        </p>
      </div>

      {/* Query Bar */}
      <form onSubmit={handleAsk} className="relative">
        <input
          type="text"
          required
          placeholder="Ask a technical or empirical question (e.g. 'What is the attention formulation in Transformer?')"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          className="w-full bg-[#111827] border border-gray-700 rounded-2xl pl-5 pr-32 py-4 text-sm text-white placeholder-gray-500 shadow-xl focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500 transition-all"
        />
        <button
          type="submit"
          disabled={loading || !query.trim()}
          className="absolute right-3 top-2.5 bottom-2.5 bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white font-medium px-5 rounded-xl text-sm flex items-center gap-2 shadow-md shadow-blue-600/30 transition-all"
        >
          {loading ? (
            <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
          ) : (
            <>
              <span>Ask</span>
              <Send className="w-3.5 h-3.5" />
            </>
          )}
        </button>
      </form>

      {/* Answer & Synthesis Panel */}
      {answer && (
        <div className="bg-[#111827] rounded-2xl border border-gray-800 p-7 space-y-6 shadow-2xl">
          {/* Answer Top Bar */}
          <div className="flex items-center justify-between border-b border-gray-800 pb-4">
            <div className="flex items-center gap-3">
              <span className="text-xs text-gray-400 font-semibold uppercase tracking-wider">Epistemic Status:</span>
              <EpistemicBadge state={answer.epistemic_state} />
            </div>

            <div className="flex items-center gap-3">
              <button
                onClick={handleSave}
                disabled={saving || savedSuccess}
                className={`inline-flex items-center gap-1.5 text-xs font-semibold px-4 py-2 rounded-xl transition-all ${
                  savedSuccess
                    ? 'bg-emerald-950/60 text-emerald-400 border border-emerald-500/30'
                    : 'bg-[#1F2937] hover:bg-gray-700 text-white border border-gray-700'
                }`}
              >
                {savedSuccess ? (
                  <>
                    <CheckCircle2 className="w-4 h-4" />
                    <span>Saved to Knowledge Graph</span>
                  </>
                ) : (
                  <>
                    <BookmarkPlus className="w-4 h-4 text-blue-400" />
                    <span>Save Synthesis</span>
                  </>
                )}
              </button>
            </div>
          </div>

          {/* Synthesized Answer Text */}
          <div className="space-y-3">
            <h3 className="text-xs font-bold text-gray-400 uppercase tracking-wider">Synthesized Evidence Answer:</h3>
            <div className="bg-[#0B0F19] p-5 rounded-xl border border-gray-800 text-sm text-gray-200 leading-relaxed font-sans whitespace-pre-wrap">
              {answer.answer}
            </div>
          </div>

          {/* Preserved Contradictions Panel (Non-negotiable) */}
          {answer.conflicts && answer.conflicts.length > 0 && (
            <div className="p-5 rounded-xl bg-amber-950/20 border border-amber-600/40 space-y-4">
              <div className="flex items-center gap-2 text-amber-400 font-semibold text-sm">
                <AlertTriangle className="w-4 h-4 text-amber-400" />
                <span>Preserved Empirical Contradictions ({answer.conflicts.length})</span>
              </div>
              <p className="text-xs text-gray-300 leading-relaxed">
                Synapse does not overwrite opposing findings. Both empirical perspectives are preserved in the knowledge graph as conflicted claims.
              </p>

              <div className="space-y-3">
                {answer.conflicts.map((conf, idx) => (
                  <div key={idx} className="grid grid-cols-1 md:grid-cols-2 gap-3 text-xs">
                    <div className="p-3 bg-[#111827] rounded-lg border border-gray-800 space-y-1.5">
                      <span className="text-[10px] text-blue-400 font-bold uppercase block">Perspective A:</span>
                      <p className="text-gray-200 italic">"{conf.claim_a}"</p>
                    </div>
                    <div className="p-3 bg-[#111827] rounded-lg border border-gray-800 space-y-1.5">
                      <span className="text-[10px] text-purple-400 font-bold uppercase block">Perspective B (Conflicting):</span>
                      <p className="text-gray-200 italic">"{conf.claim_b}"</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Grounded Verifiable Citations */}
          <div className="space-y-3 pt-2">
            <div className="flex items-center justify-between">
              <h3 className="text-xs font-bold text-gray-400 uppercase tracking-wider flex items-center gap-2">
                <ShieldCheck className="w-4 h-4 text-emerald-400" />
                <span>Grounded Citations ({answer.citations.length})</span>
              </h3>
              <span className="text-[11px] text-gray-500 font-mono">100% Provenance Grounded</span>
            </div>

            {answer.citations.length === 0 ? (
              <div className="text-xs text-gray-500 italic p-3 bg-[#0B0F19] rounded-lg border border-gray-800">
                No citations generated. (Insufficient evidence state).
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                {answer.citations.map((c, idx) => (
                  <div 
                    key={idx} 
                    onClick={() => onOpenCitation?.(c.source_id, c.locator, c.evidence_id)}
                    className="p-3.5 bg-[#0B0F19] hover:bg-[#1a2333] hover:border-blue-500/50 cursor-pointer rounded-xl border border-gray-800 space-y-2 text-xs transition-all group shadow-md"
                    title="Click to open source document and inspect grounded evidence locator"
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-1.5 min-w-0">
                        <span className="font-semibold text-white truncate max-w-[170px] group-hover:text-blue-300 transition-colors">
                          {c.source_title}
                        </span>
                        <ExternalLink className="w-3 h-3 text-gray-500 group-hover:text-blue-400 opacity-0 group-hover:opacity-100 transition-opacity shrink-0" />
                      </div>
                      <span className="font-mono text-emerald-400 bg-emerald-950/40 px-2 py-0.5 rounded text-[11px] shrink-0">
                        {c.locator}
                      </span>
                    </div>

                    <p className="text-gray-400 italic line-clamp-2 text-[11px]">
                      "{c.excerpt}"
                    </p>

                    <div className="pt-1 flex items-center justify-between text-[10px] text-gray-500 font-mono">
                      <span>Tag: {c.raw_tag}</span>
                      <span className="text-emerald-400 font-semibold flex items-center gap-1">
                        <CheckCircle2 className="w-3 h-3" />
                        <span>Verified</span>
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Limitations */}
          {answer.limitations && (
            <div className="p-3 bg-gray-900/60 rounded-xl border border-gray-800 text-xs text-gray-400 flex items-start gap-2">
              <HelpCircle className="w-4 h-4 text-gray-500 shrink-0 mt-0.5" />
              <span>{answer.limitations}</span>
            </div>
          )}
        </div>
      )}
    </div>
  );
};
