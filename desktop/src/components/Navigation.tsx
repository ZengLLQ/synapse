import React from 'react';
import { 
  FolderKanban, 
  FileText, 
  BookOpen, 
  Network, 
  FlaskConical, 
  CheckSquare, 
  History, 
  Settings,
  ShieldAlert
} from 'lucide-react';

export type NavView = 
  | 'workspaces'
  | 'sources'
  | 'reader'
  | 'graph'
  | 'studio'
  | 'review'
  | 'audit'
  | 'settings';

interface NavigationProps {
  currentView: NavView;
  onSelectView: (view: NavView) => void;
  pendingReviewCount?: number;
  hasActiveWorkspace: boolean;
}

export const Navigation: React.FC<NavigationProps> = ({
  currentView,
  onSelectView,
  pendingReviewCount = 0,
  hasActiveWorkspace
}) => {
  const navItems: Array<{ id: NavView; label: string; icon: React.ReactNode; requiresWorkspace: boolean; badge?: number }> = [
    { id: 'workspaces', label: 'Workspaces', icon: <FolderKanban className="w-5 h-5" />, requiresWorkspace: false },
    { id: 'sources', label: 'Sources', icon: <FileText className="w-5 h-5" />, requiresWorkspace: true },
    { id: 'reader', label: 'Reader', icon: <BookOpen className="w-5 h-5" />, requiresWorkspace: true },
    { id: 'graph', label: 'Evidence Graph', icon: <Network className="w-5 h-5" />, requiresWorkspace: true },
    { id: 'studio', label: 'Research Studio', icon: <FlaskConical className="w-5 h-5" />, requiresWorkspace: true },
    { id: 'review', label: 'Review Queue', icon: <CheckSquare className="w-5 h-5" />, requiresWorkspace: true, badge: pendingReviewCount },
    { id: 'audit', label: 'Audit Log', icon: <History className="w-5 h-5" />, requiresWorkspace: true },
    { id: 'settings', label: 'Settings & Cloud', icon: <Settings className="w-5 h-5" />, requiresWorkspace: true }
  ];

  return (
    <aside className="w-64 bg-[#111827] border-r border-[#1F2937] flex flex-col justify-between select-none">
      <div>
        {/* Brand Header */}
        <div className="h-16 flex items-center px-6 border-b border-[#1F2937] gap-3">
          <div className="w-8 h-8 rounded-lg bg-blue-600 flex items-center justify-center font-bold text-white shadow-lg shadow-blue-500/20">
            S
          </div>
          <div>
            <span className="font-semibold text-white tracking-wide block leading-tight">SYNAPSE</span>
            <span className="text-[10px] text-gray-400 font-mono tracking-wider block">LOCAL EVIDENCE ENGINE</span>
          </div>
        </div>

        {/* Nav Items */}
        <nav className="p-3 space-y-1">
          {navItems.map((item) => {
            const isDisabled = item.requiresWorkspace && !hasActiveWorkspace;
            const isActive = currentView === item.id;

            return (
              <button
                key={item.id}
                disabled={isDisabled}
                onClick={() => onSelectView(item.id)}
                className={`w-full flex items-center justify-between px-3.5 py-2.5 rounded-lg text-sm font-medium transition-all ${
                  isActive
                    ? 'bg-blue-600 text-white shadow-md shadow-blue-600/20'
                    : isDisabled
                    ? 'text-gray-600 cursor-not-allowed'
                    : 'text-gray-300 hover:bg-[#1F2937] hover:text-white'
                }`}
              >
                <div className="flex items-center gap-3">
                  {item.icon}
                  <span>{item.label}</span>
                </div>
                {item.badge !== undefined && item.badge > 0 && (
                  <span className={`px-2 py-0.5 text-xs font-semibold rounded-full ${
                    isActive ? 'bg-white text-blue-600' : 'bg-purple-600 text-white'
                  }`}>
                    {item.badge}
                  </span>
                )}
              </button>
            );
          })}
        </nav>
      </div>

      {/* Local-First Security Status */}
      <div className="p-4 m-3 rounded-xl bg-[#0B0F19]/60 border border-[#1F2937]/80 text-xs">
        <div className="flex items-center gap-2 text-emerald-400 font-medium mb-1">
          <ShieldAlert className="w-4 h-4" />
          <span>Local-First Enforced</span>
        </div>
        <p className="text-gray-400 leading-relaxed text-[11px]">
          Zero cloud data transmission without explicit cryptographic consent grant.
        </p>
      </div>
    </aside>
  );
};
