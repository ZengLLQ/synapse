import React, { useState, useEffect, useCallback } from 'react';
import { api } from './api/client';
import { Workspace, Source, GraphData, ReviewItem, ResearchAnswer } from './types';
import { Navigation, NavView } from './components/Navigation';
import { Header } from './components/Header';
import { WorkspaceHome } from './views/WorkspaceHome';
import { SourcesView } from './views/SourcesView';
import { ReaderView } from './views/ReaderView';
import { EvidenceGraphView } from './views/EvidenceGraphView';
import { ResearchStudio } from './views/ResearchStudio';
import { ReviewQueueView } from './views/ReviewQueueView';
import { ActivityAuditView } from './views/ActivityAuditView';
import { SettingsView } from './views/SettingsView';

export const App: React.FC = () => {
  const [currentView, setCurrentView] = useState<NavView>('workspaces');
  const [workspaces, setWorkspaces] = useState<Workspace[]>([]);
  const [activeWorkspace, setActiveWorkspace] = useState<Workspace | null>(null);
  const [sources, setSources] = useState<Source[]>([]);
  const [readerSource, setReaderSource] = useState<Source | null>(null);
  const [activeEvidenceId, setActiveEvidenceId] = useState<string | null>(null);
  const [activeLocator, setActiveLocator] = useState<string | null>(null);
  const [graphData, setGraphData] = useState<GraphData>({ nodes: [], edges: [] });
  const [reviewItems, setReviewItems] = useState<ReviewItem[]>([]);
  const [serverOnline, setServerOnline] = useState<boolean>(false);
  const [isInitializing, setIsInitializing] = useState<boolean>(true);

  // Synchronize Tauri session token and backend URL if running under Tauri
  useEffect(() => {
    const initTauriAuth = async () => {
      try {
        if (typeof window !== 'undefined' && ('__TAURI_INTERNALS__' in window || '__TAURI__' in window)) {
          const { invoke } = await import('@tauri-apps/api/core');
          const info = await invoke<{ url: string; token: string }>('get_backend_info');
          if (info && info.token) {
            api.setToken(info.token);
            if (info.url) api.setBaseUrl(info.url);
          }
        }
      } catch (err) {
        console.warn('Tauri get_backend_info not loaded or web fallback in use:', err);
      }
    };
    initTauriAuth();
  }, []);

  // Check health and load workspaces on mount
  const checkHealthAndLoadWorkspaces = useCallback(async () => {
    try {
      await api.getHealth();
      setServerOnline(true);
      const wsList = await api.listWorkspaces();
      setWorkspaces(wsList || []);

      if (wsList && wsList.length > 0 && !activeWorkspace) {
        setActiveWorkspace(wsList[0]);
      }
    } catch {
      setServerOnline(false);
    } finally {
      setIsInitializing(false);
    }
  }, [activeWorkspace]);

  useEffect(() => {
    checkHealthAndLoadWorkspaces();
    const interval = setInterval(checkHealthAndLoadWorkspaces, 10000);
    return () => clearInterval(interval);
  }, [checkHealthAndLoadWorkspaces]);

  // Load workspace-specific resources
  const loadWorkspaceResources = useCallback(async (wsId: string) => {
    try {
      const [srcList, gData, rItems] = await Promise.all([
        api.listSources(wsId).catch(() => []),
        api.getGraph(wsId).catch(() => ({ nodes: [], edges: [] })),
        api.listReviewQueue(wsId).catch(() => [])
      ]);
      setSources(srcList || []);
      setGraphData(gData || { nodes: [], edges: [] });
      setReviewItems(rItems || []);
    } catch (err) {
      console.error('Error loading workspace resources:', err);
    }
  }, []);

  useEffect(() => {
    if (activeWorkspace) {
      loadWorkspaceResources(activeWorkspace.id);
    } else {
      setSources([]);
      setGraphData({ nodes: [], edges: [] });
      setReviewItems([]);
      setReaderSource(null);
    }
  }, [activeWorkspace, loadWorkspaceResources]);

  // Workspace actions
  const handleSelectWorkspace = (ws: Workspace) => {
    setActiveWorkspace(ws);
    setCurrentView('sources');
  };

  const handleCreateWorkspace = async (name: string, path: string) => {
    const newWs = await api.createWorkspace(name, path);
    setWorkspaces(prev => [...prev, newWs]);
    setActiveWorkspace(newWs);
    setCurrentView('sources');
  };

  const handleRenameWorkspace = async (id: string, newName: string) => {
    await api.renameWorkspace(id, newName);
    setWorkspaces(prev => prev.map(w => w.id === id ? { ...w, name: newName } : w));
    if (activeWorkspace?.id === id) {
      setActiveWorkspace(prev => prev ? { ...prev, name: newName } : null);
    }
  };

  const handleArchiveWorkspace = async (id: string) => {
    try {
      await api.archiveWorkspace(id);
    } catch (err) {
      console.error('Failed to archive workspace on backend:', err);
    }
    setWorkspaces(prev => prev.filter(w => w.id !== id));
    if (activeWorkspace?.id === id) {
      const remaining = workspaces.filter(w => w.id !== id);
      setActiveWorkspace(remaining.length > 0 ? remaining[0] : null);
      if (remaining.length === 0) {
        setCurrentView('workspaces');
      }
    }
  };

  // Source actions
  const handleImportSource = async (filePath: string, title?: string) => {
    if (!activeWorkspace) return;
    await api.importSource(activeWorkspace.id, filePath, title);
    await loadWorkspaceResources(activeWorkspace.id);
  };

  const handleOpenInReader = (source: Source) => {
    setReaderSource(source);
    setActiveEvidenceId(null);
    setActiveLocator(null);
    setCurrentView('reader');
  };

  const handleOpenCitation = (sourceId: string, locator?: string, evidenceId?: string) => {
    const src = sources.find(s => s.id === sourceId);
    if (src) {
      setReaderSource(src);
    } else {
      setReaderSource({
        id: sourceId,
        workspace_id: activeWorkspace?.id || '',
        title: 'Source Document',
        format: 'plaintext',
        checksum: '',
        original_path: '',
        managed_path: '',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      });
    }
    setActiveEvidenceId(evidenceId || null);
    setActiveLocator(locator || null);
    setCurrentView('reader');
  };

  // Research actions
  const handleAskQuestion = async (question: string): Promise<ResearchAnswer> => {
    if (!activeWorkspace) throw new Error('No active workspace');
    return await api.askQuestion(activeWorkspace.id, question);
  };

  const handleSaveSynthesis = async (payload: { question: string; answer: string; limitations: string; citations: any[] }) => {
    if (!activeWorkspace) throw new Error('No active workspace');
    await api.saveSynthesis(activeWorkspace.id, payload);
    await loadWorkspaceResources(activeWorkspace.id);
  };

  // Review Queue actions
  const handleDecideReviewItem = async (itemId: string, action: 'accept' | 'reject', notes: string) => {
    if (!activeWorkspace) throw new Error('No active workspace');
    await api.decideReviewItem(activeWorkspace.id, itemId, action, notes);
    await loadWorkspaceResources(activeWorkspace.id);
  };

  const pendingCount = reviewItems.filter(i => i.status === 'pending').length;

  if (isInitializing) {
    return (
      <div className="flex h-screen items-center justify-center bg-[#0B0F19] text-white">
        <div className="flex flex-col items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-blue-600 flex items-center justify-center font-bold text-lg animate-pulse">
            S
          </div>
          <span className="text-sm font-medium tracking-wide">INITIALIZING SYNAPSE...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="flex h-screen bg-[#0B0F19] text-gray-100 font-sans antialiased overflow-hidden select-none">
      {/* Sidebar Navigation */}
      <Navigation
        currentView={currentView}
        onSelectView={(view) => setCurrentView(view)}
        pendingReviewCount={pendingCount}
        hasActiveWorkspace={Boolean(activeWorkspace)}
      />

      {/* Main Content Pane */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        <Header
          activeWorkspace={activeWorkspace}
          serverOnline={serverOnline}
          onOpenWorkspaceModal={() => setCurrentView('workspaces')}
        />

        <main className="flex-1 overflow-y-auto">
          {currentView === 'workspaces' && (
            <WorkspaceHome
              workspaces={workspaces}
              activeWorkspace={activeWorkspace}
              onSelectWorkspace={handleSelectWorkspace}
              onCreateWorkspace={handleCreateWorkspace}
              onRenameWorkspace={handleRenameWorkspace}
              onArchiveWorkspace={handleArchiveWorkspace}
            />
          )}

          {currentView === 'sources' && activeWorkspace && (
            <SourcesView
              sources={sources}
              workspaceId={activeWorkspace.id}
              onImportSource={handleImportSource}
              onOpenInReader={handleOpenInReader}
            />
          )}

          {currentView === 'reader' && (
            <ReaderView
              source={readerSource}
              workspaceId={activeWorkspace ? activeWorkspace.id : ''}
              activeEvidenceId={activeEvidenceId}
              activeLocator={activeLocator}
              onSelectOtherSource={() => setCurrentView('sources')}
            />
          )}

          {currentView === 'graph' && activeWorkspace && (
            <EvidenceGraphView
              graphData={graphData}
              workspaceId={activeWorkspace.id}
              onRefreshGraph={() => loadWorkspaceResources(activeWorkspace.id)}
            />
          )}

          {currentView === 'studio' && (
            <ResearchStudio
              onAskQuestion={handleAskQuestion}
              onSaveSynthesis={handleSaveSynthesis}
              onOpenCitation={handleOpenCitation}
            />
          )}

          {currentView === 'review' && (
            <ReviewQueueView
              items={reviewItems}
              onDecideItem={handleDecideReviewItem}
              onRefresh={() => activeWorkspace && loadWorkspaceResources(activeWorkspace.id)}
            />
          )}

          {currentView === 'audit' && activeWorkspace && (
            <ActivityAuditView
              workspaceId={activeWorkspace.id}
            />
          )}

          {currentView === 'settings' && activeWorkspace && (
            <SettingsView
              workspaceId={activeWorkspace.id}
            />
          )}
        </main>
      </div>
    </div>
  );
};
