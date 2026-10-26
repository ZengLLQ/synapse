import React, { useState, useEffect, useRef } from 'react';
import { Source, EvidenceRecord } from '../types';
import { api } from '../api/client';
import { BookOpen, MapPin, ShieldCheck, Tag, FileText, Loader2, AlertCircle } from 'lucide-react';

interface ReaderViewProps {
  workspaceId: string;
  source: Source | null;
  activeEvidenceId?: string | null;
  activeLocator?: string | null;
  onSelectOtherSource: () => void;
}

export const ReaderView: React.FC<ReaderViewProps> = ({
  workspaceId,
  source,
  activeEvidenceId,
  activeLocator,
  onSelectOtherSource
}) => {
  const [, setContent] = useState<string>('');
  const [lines, setLines] = useState<string[]>([]);
  const [evidenceList, setEvidenceList] = useState<EvidenceRecord[]>([]);
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  const [selectedSpan, setSelectedSpan] = useState<{ lines: string; text: string; id: string; chars: string } | null>(null);

  const activeLineRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!source || !workspaceId) {
      setContent('');
      setLines([]);
      setEvidenceList([]);
      setSelectedSpan(null);
      return;
    }

    let isMounted = true;
    const fetchDocAndEvidence = async () => {
      setLoading(true);
      setError(null);
      try {
        const [contentRes, evRes] = await Promise.all([
          api.getSourceContent(workspaceId, source.id).catch(() => ({ source, content: '' })),
          api.getSourceEvidence(workspaceId, source.id).catch(() => [])
        ]);

        if (!isMounted) return;

        const docText = contentRes?.content || '';
        setContent(docText);
        const splitLines = docText.split('\n');
        setLines(splitLines);
        setEvidenceList(evRes || []);

        // Auto-select evidence if activeEvidenceId or activeLocator provided
        if (evRes && evRes.length > 0) {
          let matched = evRes.find(e => e.id === activeEvidenceId);
          if (!matched && activeLocator) {
            matched = evRes.find(e => {
              const locStr = `lines ${e.start_line}-${e.end_line}`;
              return activeLocator.includes(locStr) || activeLocator.includes(`line ${e.start_line}`);
            });
          }
          if (!matched) {
            matched = evRes[0];
          }

          if (matched) {
            setSelectedSpan({
              lines: `lines ${matched.start_line}-${matched.end_line}`,
              text: matched.excerpt,
              id: matched.id,
              chars: `chars ${matched.start_char}-${matched.end_char}`
            });
          }
        } else {
          setSelectedSpan(null);
        }
      } catch (err: any) {
        if (isMounted) {
          setError(err?.message || 'Failed to load source document');
        }
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    };

    fetchDocAndEvidence();
    return () => { isMounted = false; };
  }, [workspaceId, source?.id, activeEvidenceId, activeLocator]);

  // Scroll active line into view
  useEffect(() => {
    if (activeLineRef.current) {
      activeLineRef.current.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
  }, [selectedSpan]);

  if (!source) {
    return (
      <div className="p-8 max-w-4xl mx-auto text-center py-24 space-y-4">
        <BookOpen className="w-16 h-16 text-gray-600 mx-auto" />
        <h2 className="text-xl font-bold text-white">No Document Open</h2>
        <p className="text-sm text-gray-400 max-w-md mx-auto">
          Select a source document from the Sources view to inspect text spans, line locators, and verifiable citations.
        </p>
        <button
          onClick={onSelectOtherSource}
          className="bg-blue-600 hover:bg-blue-500 text-white font-medium px-4 py-2 rounded-xl text-sm"
        >
          Go to Sources
        </button>
      </div>
    );
  }

  // Find evidence covering a specific line number
  const findEvidenceForLine = (lineNum: number) => {
    return evidenceList.find(e => e.start_line <= lineNum && lineNum <= e.end_line);
  };

  return (
    <div className="h-[calc(100vh-4rem)] flex overflow-hidden">
      {/* Main Document Reading Panel */}
      <div className="flex-1 flex flex-col border-r border-gray-800 bg-[#0B0F19] overflow-hidden">
        {/* Document Header Bar */}
        <div className="h-14 px-6 border-b border-gray-800 bg-[#111827] flex items-center justify-between shrink-0">
          <div className="flex items-center gap-2">
            <FileText className="w-4 h-4 text-blue-400" />
            <h2 className="text-sm font-semibold text-white truncate max-w-md">{source.title}</h2>
            <span className="text-xs text-gray-500 uppercase font-mono px-2 py-0.5 rounded bg-gray-800">
              {source.format}
            </span>
          </div>

          <div className="flex items-center gap-3">
            <span className="text-xs text-gray-400 font-mono">
              Managed: {source.managed_path.split(/[\\/]/).pop()}
            </span>
            <button
              onClick={onSelectOtherSource}
              className="text-xs text-blue-400 hover:text-blue-300 font-medium"
            >
              Switch Document
            </button>
          </div>
        </div>

        {/* Loading / Error States */}
        {loading ? (
          <div className="flex-1 flex items-center justify-center text-gray-400 gap-2 font-mono text-xs">
            <Loader2 className="w-5 h-5 animate-spin text-blue-400" />
            <span>Loading document content and locators...</span>
          </div>
        ) : error ? (
          <div className="p-8 text-center text-red-400 space-y-2">
            <AlertCircle className="w-8 h-8 mx-auto" />
            <p className="text-sm">{error}</p>
          </div>
        ) : lines.length === 0 ? (
          <div className="p-8 text-center text-gray-500 text-sm">
            This document has empty content or could not be loaded from managed storage.
          </div>
        ) : (
          /* Real Text Area with Line Numbers */
          <div className="flex-1 overflow-y-auto p-6 font-mono text-sm leading-relaxed space-y-1">
            {lines.map((text, idx) => {
              const lineNum = idx + 1;
              const ev = findEvidenceForLine(lineNum);
              const isSelected = selectedSpan?.id === ev?.id;

              return (
                <div 
                  key={lineNum}
                  ref={isSelected ? activeLineRef : null}
                  onClick={() => {
                    if (ev) {
                      setSelectedSpan({
                        lines: `lines ${ev.start_line}-${ev.end_line}`,
                        text: ev.excerpt,
                        id: ev.id,
                        chars: `chars ${ev.start_char}-${ev.end_char}`
                      });
                    } else {
                      setSelectedSpan({
                        lines: `line ${lineNum}`,
                        text: text.trim() || `(empty line ${lineNum})`,
                        id: `line-${lineNum}`,
                        chars: `line ${lineNum}`
                      });
                    }
                  }}
                  className={`flex items-start gap-4 px-2 py-1 rounded transition-colors cursor-pointer ${
                    isSelected
                      ? 'bg-blue-900/40 border-l-2 border-blue-400 text-blue-100 font-medium'
                      : ev
                      ? 'bg-emerald-950/20 border-l-2 border-emerald-500/60 text-emerald-100 hover:bg-emerald-900/30'
                      : 'text-gray-300 hover:bg-gray-800/30'
                  }`}
                >
                  <span className="text-xs text-gray-600 select-none w-8 text-right font-mono shrink-0">
                    {lineNum}
                  </span>
                  <span className="whitespace-pre-wrap flex-1">{text || ' '}</span>
                  {ev && (
                    <span className="text-[10px] uppercase font-mono px-1.5 py-0.5 rounded bg-emerald-950/70 text-emerald-400 border border-emerald-800/50 shrink-0">
                      Evidence
                    </span>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Right Evidence Inspector Sidebar */}
      <div className="w-96 bg-[#111827] flex flex-col shrink-0 overflow-y-auto p-6 space-y-6">
        <div>
          <h3 className="text-sm font-bold text-white uppercase tracking-wider flex items-center gap-2">
            <MapPin className="w-4 h-4 text-emerald-400" />
            <span>Provenance Inspector</span>
          </h3>
          <p className="text-xs text-gray-400 mt-1">
            Exact character and line offsets grounding knowledge graph claims.
          </p>
        </div>

        {/* Selected Evidence Card */}
        {selectedSpan ? (
          <div className="bg-[#1F2937] p-4 rounded-xl border border-gray-700 space-y-3 shadow-lg">
            <div className="flex items-center justify-between">
              <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-emerald-400 bg-emerald-950/60 px-2.5 py-0.5 rounded-full border border-emerald-500/30">
                <ShieldCheck className="w-3.5 h-3.5" />
                <span>Grounded Evidence Span</span>
              </span>
              <span className="text-xs font-mono text-gray-400">{selectedSpan.lines}</span>
            </div>

            <p className="text-xs text-gray-200 bg-[#0B0F19] p-3 rounded-lg border border-gray-800 italic leading-relaxed">
              "{selectedSpan.text}"
            </p>

            <div className="space-y-1.5 pt-1">
              <span className="text-[10px] text-gray-400 uppercase font-bold tracking-wider">Citation Tag:</span>
              <div className="font-mono text-xs text-blue-400 bg-[#0B0F19] px-2.5 py-1.5 rounded border border-gray-800 select-all">
                [cite:src:{source.id}#ev:{selectedSpan.id}]
              </div>
            </div>

            <div className="text-[11px] font-mono text-gray-400">
              Offset: {selectedSpan.chars}
            </div>
          </div>
        ) : (
          <div className="text-center py-8 text-xs text-gray-500 border border-dashed border-gray-800 rounded-xl p-4">
            Click on any line in the document to inspect its grounded evidence locator.
          </div>
        )}

        {/* Source Metadata */}
        <div className="space-y-3 pt-4 border-t border-gray-800">
          <h4 className="text-xs font-semibold text-gray-300 uppercase tracking-wider flex items-center gap-1.5">
            <Tag className="w-3.5 h-3.5 text-blue-400" />
            <span>Document Fingerprint</span>
          </h4>

          <div className="space-y-2 text-xs font-mono">
            <div>
              <span className="text-gray-500 block text-[10px]">SOURCE ID</span>
              <span className="text-gray-300 break-all">{source.id}</span>
            </div>
            <div>
              <span className="text-gray-500 block text-[10px]">SHA-256 CHECKSUM</span>
              <span className="text-gray-300 break-all">{source.checksum}</span>
            </div>
            <div>
              <span className="text-gray-500 block text-[10px]">MANAGED PATH</span>
              <span className="text-gray-300 break-all">{source.managed_path}</span>
            </div>
            <div>
              <span className="text-gray-500 block text-[10px]">EVIDENCE RECORDS</span>
              <span className="text-emerald-400">{evidenceList.length} grounded span(s)</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

