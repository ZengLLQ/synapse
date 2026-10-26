import React from 'react';
import { Workspace } from '../types';
import { Database, Activity, FolderOpen } from 'lucide-react';

interface HeaderProps {
  activeWorkspace: Workspace | null;
  serverOnline: boolean;
  onOpenWorkspaceModal: () => void;
}

export const Header: React.FC<HeaderProps> = ({
  activeWorkspace,
  serverOnline,
  onOpenWorkspaceModal
}) => {
  return (
    <header className="h-16 bg-[#111827] border-b border-[#1F2937] px-6 flex items-center justify-between">
      <div className="flex items-center gap-4">
        {activeWorkspace ? (
          <div className="flex items-center gap-3">
            <span className="text-xs text-gray-400 uppercase tracking-wider font-semibold">Active:</span>
            <div className="flex items-center gap-2 bg-[#1F2937] px-3 py-1.5 rounded-lg border border-gray-700">
              <Database className="w-4 h-4 text-blue-400" />
              <span className="text-sm font-medium text-white">{activeWorkspace.name}</span>
            </div>
            <button
              onClick={onOpenWorkspaceModal}
              className="p-1.5 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors"
              title="Switch Workspace"
            >
              <FolderOpen className="w-4 h-4" />
            </button>
          </div>
        ) : (
          <div className="flex items-center gap-2 text-sm text-amber-400">
            <span>No workspace selected. Select or create one to begin.</span>
          </div>
        )}
      </div>

      <div className="flex items-center gap-5">
        <div className="flex items-center gap-2 text-xs">
          <div className={`w-2.5 h-2.5 rounded-full ${serverOnline ? 'bg-emerald-500 animate-pulse' : 'bg-red-500'}`} />
          <span className="text-gray-300 font-mono">
            {serverOnline ? 'Julia Backend Connected (127.0.0.1:8765)' : 'Backend Offline'}
          </span>
        </div>

        <div className="h-4 w-px bg-gray-700" />

        <div className="flex items-center gap-2 text-xs text-gray-400">
          <Activity className="w-3.5 h-3.5 text-blue-400" />
          <span>FTS5 Active</span>
        </div>
      </div>
    </header>
  );
};
