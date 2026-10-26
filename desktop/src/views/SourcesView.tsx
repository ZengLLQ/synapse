import React, { useState } from 'react';
import { Source } from '../types';
import { 
  FileText, 
  Upload, 
  Copy, 
  Check, 
  ExternalLink, 
  FileCode, 
  File 
} from 'lucide-react';

interface SourcesViewProps {
  sources: Source[];
  workspaceId: string;
  onImportSource: (filePath: string, title?: string) => Promise<void>;
  onOpenInReader: (source: Source) => void;
}

export const SourcesView: React.FC<SourcesViewProps> = ({
  sources,
  onImportSource,
  onOpenInReader
}) => {
  const [showImportModal, setShowImportModal] = useState(false);
  const [filePath, setFilePath] = useState('');
  const [title, setTitle] = useState('');
  const [importing, setImporting] = useState(false);
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const handleImport = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!filePath.trim()) return;
    setImporting(true);
    try {
      await onImportSource(filePath.trim(), title.trim() || undefined);
      setShowImportModal(false);
      setFilePath('');
      setTitle('');
    } catch (err: any) {
      alert(`Import failed: ${err.message}`);
    } finally {
      setImporting(false);
    }
  };

  const copyChecksum = (checksum: string, id: string) => {
    navigator.clipboard.writeText(checksum);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const getFormatBadge = (format: string) => {
    switch (format) {
      case 'markdown':
        return (
          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-950/60 text-blue-400 border border-blue-800/40">
            <FileCode className="w-3 h-3" />
            <span>Markdown</span>
          </span>
        );
      case 'pdf':
        return (
          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium bg-rose-950/60 text-rose-400 border border-rose-800/40">
            <File className="w-3 h-3" />
            <span>PDF</span>
          </span>
        );
      default:
        return (
          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-800 text-gray-300 border border-gray-700">
            <FileText className="w-3 h-3" />
            <span>Plain Text</span>
          </span>
        );
    }
  };

  return (
    <div className="p-8 max-w-6xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2.5">
            <FileText className="w-6 h-6 text-blue-400" />
            <span>Document Sources</span>
          </h1>
          <p className="text-sm text-gray-400 mt-1">
            Imported literature, parsed sections, and cryptographic SHA-256 deduplication registry.
          </p>
        </div>

        <button
          onClick={() => setShowImportModal(true)}
          className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-500 text-white font-medium px-4 py-2 rounded-xl shadow-lg shadow-blue-600/30 transition-all text-sm"
        >
          <Upload className="w-4 h-4" />
          <span>Import Source File</span>
        </button>
      </div>

      {/* Sources Table */}
      {sources.length === 0 ? (
        <div className="text-center py-20 bg-[#111827] rounded-2xl border border-gray-800 p-8 space-y-3">
          <FileText className="w-12 h-12 text-gray-600 mx-auto" />
          <h3 className="text-base font-medium text-gray-200">No sources imported</h3>
          <p className="text-sm text-gray-400 max-w-md mx-auto">
            Import Markdown, text files, or PDFs to parse sections, extract candidate entities, and ground your research.
          </p>
          <button
            onClick={() => setShowImportModal(true)}
            className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-500 text-white font-medium px-4 py-2 rounded-lg text-sm mt-2"
          >
            <Upload className="w-4 h-4" />
            <span>Import First Document</span>
          </button>
        </div>
      ) : (
        <div className="bg-[#111827] rounded-2xl border border-gray-800 overflow-hidden shadow-xl">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="border-b border-gray-800 bg-[#0B0F19]/50 text-xs text-gray-400 uppercase tracking-wider font-semibold">
                <th className="py-3.5 px-6">Document Title</th>
                <th className="py-3.5 px-4">Format</th>
                <th className="py-3.5 px-4 font-mono">SHA-256 Checksum</th>
                <th className="py-3.5 px-4">Imported</th>
                <th className="py-3.5 px-6 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-800/80 text-sm">
              {sources.map((src) => (
                <tr key={src.id} className="hover:bg-gray-800/40 transition-colors">
                  <td className="py-4 px-6">
                    <div className="font-medium text-white">{src.title}</div>
                    <div className="text-xs text-gray-500 font-mono truncate max-w-xs">{src.original_path}</div>
                  </td>
                  <td className="py-4 px-4">{getFormatBadge(src.format)}</td>
                  <td className="py-4 px-4">
                    <button
                      onClick={() => copyChecksum(src.checksum, src.id)}
                      className="group inline-flex items-center gap-1.5 font-mono text-xs text-gray-400 hover:text-white bg-[#0B0F19] px-2 py-1 rounded border border-gray-800"
                      title="Copy SHA-256 Checksum"
                    >
                      <span>{src.checksum.slice(0, 12)}...{src.checksum.slice(-8)}</span>
                      {copiedId === src.id ? (
                        <Check className="w-3.5 h-3.5 text-emerald-400" />
                      ) : (
                        <Copy className="w-3.5 h-3.5 opacity-0 group-hover:opacity-100 transition-opacity" />
                      )}
                    </button>
                  </td>
                  <td className="py-4 px-4 text-xs text-gray-400">
                    {new Date(src.created_at).toLocaleDateString()}
                  </td>
                  <td className="py-4 px-6 text-right">
                    <button
                      onClick={() => onOpenInReader(src)}
                      className="inline-flex items-center gap-1.5 text-xs font-semibold bg-gray-800 hover:bg-gray-700 text-blue-400 px-3 py-1.5 rounded-lg border border-gray-700 transition-colors"
                    >
                      <ExternalLink className="w-3.5 h-3.5" />
                      <span>Read & Ground</span>
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Import Modal */}
      {showImportModal && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div className="bg-[#111827] border border-gray-700 rounded-2xl w-full max-w-lg p-6 shadow-2xl space-y-5">
            <h3 className="text-lg font-bold text-white flex items-center gap-2">
              <Upload className="w-5 h-5 text-blue-400" />
              <span>Import Document into Synapse</span>
            </h3>

            <div className="p-3 bg-blue-950/30 border border-blue-800/40 rounded-xl text-xs text-blue-300 leading-relaxed">
              Files are copied to the managed workspace directory with cryptographic SHA-256 deduplication. 
              Duplicate uploads point to existing version records without redundant storage.
            </div>

            <form onSubmit={handleImport} className="space-y-4">
              <div>
                <label className="block text-xs font-medium text-gray-300 mb-1.5">File Path (Absolute)</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. f:/Synapse/backend/benchmarks/fixtures/attention_is_all_you_need.md"
                  value={filePath}
                  onChange={(e) => setFilePath(e.target.value)}
                  className="w-full bg-[#1F2937] border border-gray-700 rounded-lg px-3.5 py-2 text-xs font-mono text-white focus:outline-none focus:border-blue-500"
                />
              </div>

              <div>
                <label className="block text-xs font-medium text-gray-300 mb-1.5">Custom Title (Optional)</label>
                <input
                  type="text"
                  placeholder="Leave empty to use document filename or header"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  className="w-full bg-[#1F2937] border border-gray-700 rounded-lg px-3.5 py-2 text-sm text-white focus:outline-none focus:border-blue-500"
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-4 border-t border-gray-800">
                <button
                  type="button"
                  onClick={() => setShowImportModal(false)}
                  className="px-4 py-2 text-sm text-gray-400 hover:text-white"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={importing}
                  className="bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white font-medium px-5 py-2 rounded-lg text-sm shadow-md shadow-blue-600/30"
                >
                  {importing ? 'Processing & Chunking...' : 'Import & Index'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
