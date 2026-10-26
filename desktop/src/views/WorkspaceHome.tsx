import React, { useState } from 'react';
import { Workspace } from '../types';
import { FolderKanban, Plus, Check, Archive, ArrowRight, Shield, Database, Edit2 } from 'lucide-react';

interface WorkspaceHomeProps {
  workspaces: Workspace[];
  activeWorkspace: Workspace | null;
  onSelectWorkspace: (ws: Workspace) => void;
  onCreateWorkspace: (name: string, path: string) => Promise<void>;
  onRenameWorkspace: (id: string, newName: string) => Promise<void>;
  onArchiveWorkspace: (id: string) => Promise<void>;
}

export const WorkspaceHome: React.FC<WorkspaceHomeProps> = ({
  workspaces,
  activeWorkspace,
  onSelectWorkspace,
  onCreateWorkspace,
  onRenameWorkspace,
  onArchiveWorkspace
}) => {
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [renamingWs, setRenamingWs] = useState<Workspace | null>(null);
  const [renameInput, setRenameInput] = useState('');
  const [name, setName] = useState('');
  const [targetPath, setTargetPath] = useState('f:/Synapse/research_ws');
  const [creating, setCreating] = useState(false);
  const [renaming, setRenaming] = useState(false);

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim() || !targetPath.trim()) return;
    setCreating(true);
    try {
      await onCreateWorkspace(name.trim(), targetPath.trim());
      setShowCreateModal(false);
      setName('');
    } catch (err: any) {
      alert(`Failed to create workspace: ${err.message}`);
    } finally {
      setCreating(false);
    }
  };

  return (
    <div className="p-8 max-w-6xl mx-auto space-y-8">
      {/* Banner */}
      <div className="bg-gradient-to-r from-blue-900/30 via-[#111827] to-[#111827] p-8 rounded-2xl border border-blue-500/20 shadow-xl">
        <div className="max-w-3xl space-y-4">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-blue-500/10 border border-blue-500/30 text-blue-400 text-xs font-semibold">
            <Shield className="w-3.5 h-3.5" />
            <span>Local-First Desktop Research Engine</span>
          </div>
          <h1 className="text-3xl font-bold text-white tracking-tight">
            Evidence-Graph Knowledge Architecture
          </h1>
          <p className="text-gray-300 text-sm leading-relaxed">
            Synapse grounds all claims, concepts, and empirical findings in verifiable source locators. 
            Isolated workspaces maintain SQLite databases, FTS5 indexes, and deterministic audit trails locally on your machine.
          </p>
          <div className="pt-2">
            <button
              onClick={() => setShowCreateModal(true)}
              className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-500 text-white font-medium px-5 py-2.5 rounded-xl shadow-lg shadow-blue-600/30 transition-all text-sm"
            >
              <Plus className="w-4 h-4" />
              <span>Create New Workspace</span>
            </button>
          </div>
        </div>
      </div>

      {/* Workspaces Grid */}
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-semibold text-white flex items-center gap-2">
            <FolderKanban className="w-5 h-5 text-blue-400" />
            <span>Your Workspaces</span>
          </h2>
          <span className="text-xs text-gray-400 font-mono">
            {workspaces.length} workspace{workspaces.length !== 1 ? 's' : ''} available
          </span>
        </div>

        {workspaces.length === 0 ? (
          <div className="text-center py-16 bg-[#111827] rounded-2xl border border-gray-800 p-8 space-y-3">
            <Database className="w-12 h-12 text-gray-600 mx-auto" />
            <h3 className="text-base font-medium text-gray-200">No active workspaces</h3>
            <p className="text-sm text-gray-400 max-w-md mx-auto">
              Create your first workspace to begin importing literature, chunking text, and exploring grounded evidence graphs.
            </p>
            <button
              onClick={() => setShowCreateModal(true)}
              className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-500 text-white font-medium px-4 py-2 rounded-lg text-sm mt-2"
            >
              <Plus className="w-4 h-4" />
              <span>Create Workspace</span>
            </button>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
            {workspaces.map((ws) => {
              const isActive = activeWorkspace?.id === ws.id;

              return (
                <div
                  key={ws.id}
                  className={`p-5 rounded-xl border transition-all flex flex-col justify-between ${
                    isActive
                      ? 'bg-[#1F2937]/90 border-blue-500 shadow-lg shadow-blue-500/10'
                      : 'bg-[#111827] border-gray-800 hover:border-gray-700'
                  }`}
                >
                  <div className="space-y-3">
                    <div className="flex items-start justify-between">
                      <h3 className="font-semibold text-white text-base leading-snug">{ws.name}</h3>
                      {isActive && (
                        <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-emerald-400 bg-emerald-950/60 border border-emerald-500/30 px-2 py-0.5 rounded-full">
                          <Check className="w-3 h-3" />
                          <span>Active</span>
                        </span>
                      )}
                    </div>

                    <div className="text-xs text-gray-400 font-mono break-all bg-[#0B0F19] p-2.5 rounded-lg border border-gray-800/80">
                      {ws.path}
                    </div>

                    <div className="text-[11px] text-gray-500">
                      Created: {new Date(ws.created_at).toLocaleDateString()}
                    </div>
                  </div>

                  <div className="pt-5 flex items-center justify-between border-t border-gray-800 mt-4">
                    <div className="flex items-center gap-3">
                      <button
                        onClick={() => {
                          setRenamingWs(ws);
                          setRenameInput(ws.name);
                        }}
                        className="text-xs text-gray-400 hover:text-blue-400 flex items-center gap-1 transition-colors"
                        title="Rename workspace"
                      >
                        <Edit2 className="w-3.5 h-3.5" />
                        <span>Rename</span>
                      </button>

                      <button
                        onClick={() => onArchiveWorkspace(ws.id)}
                        className="text-xs text-gray-400 hover:text-red-400 flex items-center gap-1 transition-colors"
                        title="Archive workspace"
                      >
                        <Archive className="w-3.5 h-3.5" />
                        <span>Archive</span>
                      </button>
                    </div>

                    <button
                      onClick={() => onSelectWorkspace(ws)}
                      disabled={isActive}
                      className={`inline-flex items-center gap-1.5 text-xs font-semibold px-3 py-1.5 rounded-lg transition-all ${
                        isActive
                          ? 'text-gray-400 cursor-default'
                          : 'bg-blue-600 hover:bg-blue-500 text-white'
                      }`}
                    >
                      <span>{isActive ? 'Current' : 'Open Workspace'}</span>
                      {!isActive && <ArrowRight className="w-3.5 h-3.5" />}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Rename Workspace Modal */}
      {renamingWs && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div className="bg-[#111827] border border-gray-700 rounded-2xl w-full max-w-md p-6 shadow-2xl space-y-5">
            <h3 className="text-lg font-bold text-white flex items-center gap-2">
              <Edit2 className="w-5 h-5 text-blue-400" />
              <span>Rename Workspace</span>
            </h3>
            <form onSubmit={async (e) => {
              e.preventDefault();
              if (!renameInput.trim() || renaming) return;
              setRenaming(true);
              try {
                await onRenameWorkspace(renamingWs.id, renameInput.trim());
                setRenamingWs(null);
              } catch (err: any) {
                alert(`Failed to rename workspace: ${err.message}`);
              } finally {
                setRenaming(false);
              }
            }} className="space-y-4">
              <div>
                <label className="block text-xs font-medium text-gray-300 mb-1.5">Workspace Name</label>
                <input
                  type="text"
                  required
                  value={renameInput}
                  onChange={(e) => setRenameInput(e.target.value)}
                  className="w-full bg-[#1F2937] border border-gray-700 rounded-lg px-3.5 py-2 text-sm text-white focus:outline-none focus:border-blue-500"
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-4 border-t border-gray-800">
                <button
                  type="button"
                  onClick={() => setRenamingWs(null)}
                  className="px-4 py-2 text-sm text-gray-400 hover:text-white"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={renaming || !renameInput.trim()}
                  className="bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white font-medium px-4 py-2 rounded-lg text-sm shadow-md shadow-blue-600/30"
                >
                  {renaming ? 'Renaming...' : 'Save Name'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Create Workspace Modal */}
      {showCreateModal && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div className="bg-[#111827] border border-gray-700 rounded-2xl w-full max-w-md p-6 shadow-2xl space-y-5">
            <h3 className="text-lg font-bold text-white">Create Research Workspace</h3>
            <form onSubmit={handleCreate} className="space-y-4">
              <div>
                <label className="block text-xs font-medium text-gray-300 mb-1.5">Workspace Name</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Deep Learning & Transformers"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="w-full bg-[#1F2937] border border-gray-700 rounded-lg px-3.5 py-2 text-sm text-white focus:outline-none focus:border-blue-500"
                />
              </div>

              <div>
                <label className="block text-xs font-medium text-gray-300 mb-1.5">Local Storage Path</label>
                <input
                  type="text"
                  required
                  placeholder="f:/Synapse/workspace_name"
                  value={targetPath}
                  onChange={(e) => setTargetPath(e.target.value)}
                  className="w-full bg-[#1F2937] border border-gray-700 rounded-lg px-3.5 py-2 text-xs font-mono text-white focus:outline-none focus:border-blue-500"
                />
                <span className="text-[11px] text-gray-500 mt-1 block">
                  Path traversal characters like '..' are strictly rejected for security.
                </span>
              </div>

              <div className="flex items-center justify-end gap-3 pt-4 border-t border-gray-800">
                <button
                  type="button"
                  onClick={() => setShowCreateModal(false)}
                  className="px-4 py-2 text-sm text-gray-400 hover:text-white"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={creating}
                  className="bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white font-medium px-4 py-2 rounded-lg text-sm shadow-md shadow-blue-600/30"
                >
                  {creating ? 'Creating...' : 'Create Workspace'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
