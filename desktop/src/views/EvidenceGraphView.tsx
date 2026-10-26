import React, { useState, useEffect } from 'react';
import { GraphData, GraphNode } from '../types';
import { EpistemicBadge } from '../components/EpistemicBadge';
import { 
  Network, 
  Search, 
  Filter, 
  AlertTriangle, 
  ShieldCheck, 
  ArrowRight,
  Info
} from 'lucide-react';

interface EvidenceGraphViewProps {
  graphData: GraphData;
  workspaceId: string;
  onRefreshGraph: () => void;
}

export const EvidenceGraphView: React.FC<EvidenceGraphViewProps> = ({
  graphData,
  onRefreshGraph
}) => {
  const [selectedNode, setSelectedNode] = useState<GraphNode | null>(null);
  const [filterType, setFilterType] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState('');

  // Default select first node if available
  useEffect(() => {
    if (graphData.nodes.length > 0 && !selectedNode) {
      setSelectedNode(graphData.nodes[0]);
    }
  }, [graphData.nodes]);

  const filteredNodes = graphData.nodes.filter(n => {
    const matchesFilter = filterType === 'all' || n.type === filterType;
    const matchesSearch = searchQuery === '' || 
      n.label.toLowerCase().includes(searchQuery.toLowerCase()) ||
      n.description.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesFilter && matchesSearch;
  });

  const getNodeColor = (type: string, epistemicState: string) => {
    if (epistemicState === 'conflicted') return '#F59E0B'; // Amber
    switch (type) {
      case 'concept': return '#3B82F6'; // Blue
      case 'claim': return '#8B5CF6'; // Purple
      case 'method': return '#10B981'; // Emerald
      case 'study': return '#EC4899'; // Pink
      case 'source': return '#6B7280'; // Gray
      default: return '#3B82F6';
    }
  };

  const getEdgeStroke = (relationType: string) => {
    switch (relationType) {
      case 'contradicts': return '#EF4444'; // Red
      case 'supports': return '#10B981'; // Emerald
      case 'qualifies': return '#F59E0B'; // Amber
      default: return '#4B5563'; // Slate
    }
  };

  return (
    <div className="h-[calc(100vh-4rem)] flex overflow-hidden">
      {/* Canvas Area */}
      <div className="flex-1 flex flex-col bg-[#0B0F19] overflow-hidden">
        {/* Top Controls Toolbar */}
        <div className="h-14 px-6 border-b border-gray-800 bg-[#111827] flex items-center justify-between shrink-0 gap-4">
          <div className="flex items-center gap-3">
            <Network className="w-5 h-5 text-blue-400" />
            <h2 className="text-sm font-semibold text-white">Evidence Knowledge Graph</h2>
            <span className="text-xs text-gray-400 font-mono">
              ({filteredNodes.length} nodes, {graphData.edges.length} edges)
            </span>
          </div>

          <div className="flex items-center gap-3">
            {/* Search */}
            <div className="relative">
              <Search className="w-3.5 h-3.5 text-gray-400 absolute left-3 top-2.5" />
              <input
                type="text"
                placeholder="Search nodes..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="bg-[#1F2937] border border-gray-700 text-xs text-white pl-8 pr-3 py-1.5 rounded-lg focus:outline-none focus:border-blue-500 w-44"
              />
            </div>

            {/* Type Filter */}
            <div className="flex items-center gap-1.5 bg-[#1F2937] border border-gray-700 rounded-lg px-2 py-1 text-xs">
              <Filter className="w-3.5 h-3.5 text-gray-400" />
              <select
                value={filterType}
                onChange={(e) => setFilterType(e.target.value)}
                className="bg-transparent text-gray-300 focus:outline-none text-xs"
              >
                <option value="all">All Types</option>
                <option value="concept">Concepts</option>
                <option value="claim">Claims</option>
                <option value="method">Methods</option>
                <option value="study">Studies</option>
                <option value="source">Sources</option>
              </select>
            </div>

            <button
              onClick={onRefreshGraph}
              className="text-xs bg-gray-800 hover:bg-gray-700 text-gray-300 px-3 py-1.5 rounded-lg border border-gray-700 transition-colors"
            >
              Refresh
            </button>
          </div>
        </div>

        {/* Interactive SVG Canvas */}
        <div className="flex-1 relative overflow-hidden bg-radial from-[#111827]/30 to-[#0B0F19]">
          <svg className="w-full h-full cursor-crosshair">
            <defs>
              <marker
                id="arrow-default"
                viewBox="0 0 10 10"
                refX="20"
                refY="5"
                markerWidth="6"
                markerHeight="6"
                orient="auto-start-reverse"
              >
                <path d="M 0 0 L 10 5 L 0 10 z" fill="#4B5563" />
              </marker>
              <marker
                id="arrow-contradicts"
                viewBox="0 0 10 10"
                refX="20"
                refY="5"
                markerWidth="6"
                markerHeight="6"
                orient="auto-start-reverse"
              >
                <path d="M 0 0 L 10 5 L 0 10 z" fill="#EF4444" />
              </marker>
              <marker
                id="arrow-supports"
                viewBox="0 0 10 10"
                refX="20"
                refY="5"
                markerWidth="6"
                markerHeight="6"
                orient="auto-start-reverse"
              >
                <path d="M 0 0 L 10 5 L 0 10 z" fill="#10B981" />
              </marker>
            </defs>

            {/* Render Edges */}
            {graphData.edges.map((edge, idx) => {
              const srcIdx = filteredNodes.findIndex(n => n.id === edge.source);
              const tgtIdx = filteredNodes.findIndex(n => n.id === edge.target);
              if (srcIdx === -1 || tgtIdx === -1) return null;

              // Calculate circular grid coordinates for aesthetic layout
              const total = filteredNodes.length;
              const radius = 240;
              const centerX = 380;
              const centerY = 280;

              const angleSrc = (srcIdx / total) * 2 * Math.PI;
              const x1 = centerX + radius * Math.cos(angleSrc);
              const y1 = centerY + radius * Math.sin(angleSrc);

              const angleTgt = (tgtIdx / total) * 2 * Math.PI;
              const x2 = centerX + radius * Math.cos(angleTgt);
              const y2 = centerY + radius * Math.sin(angleTgt);

              const stroke = getEdgeStroke(edge.relation_type);
              const isContradiction = edge.relation_type === 'contradicts';

              return (
                <g key={edge.id || idx}>
                  <line
                    x1={x1}
                    y1={y1}
                    x2={x2}
                    y2={y2}
                    stroke={stroke}
                    strokeWidth={isContradiction ? 2.5 : 1.5}
                    strokeDasharray={isContradiction ? '4 3' : undefined}
                    opacity={0.7}
                    markerEnd={isContradiction ? 'url(#arrow-contradicts)' : (edge.relation_type === 'supports' ? 'url(#arrow-supports)' : 'url(#arrow-default)')}
                  />
                  {/* Midpoint Label */}
                  <text
                    x={(x1 + x2) / 2}
                    y={(y1 + y2) / 2 - 4}
                    fill={stroke}
                    fontSize="10"
                    textAnchor="middle"
                    className="font-mono font-semibold select-none"
                  >
                    {edge.relation_type}
                  </text>
                </g>
              );
            })}

            {/* Render Nodes */}
            {filteredNodes.map((node, idx) => {
              const total = filteredNodes.length;
              const radius = 240;
              const centerX = 380;
              const centerY = 280;

              const angle = (idx / total) * 2 * Math.PI;
              const cx = centerX + radius * Math.cos(angle);
              const cy = centerY + radius * Math.sin(angle);

              const isSelected = selectedNode?.id === node.id;
              const color = getNodeColor(node.type, node.epistemic_state);

              return (
                <g 
                  key={node.id} 
                  onClick={() => setSelectedNode(node)}
                  className="cursor-pointer group"
                >
                  <circle
                    cx={cx}
                    cy={cy}
                    r={isSelected ? 20 : 16}
                    fill={color}
                    fillOpacity={0.25}
                    stroke={color}
                    strokeWidth={isSelected ? 3 : 1.8}
                    className="transition-all group-hover:scale-110"
                  />
                  <circle
                    cx={cx}
                    cy={cy}
                    r={6}
                    fill={color}
                  />
                  <text
                    x={cx}
                    y={cy + 28}
                    fill="#F3F4F6"
                    fontSize="11"
                    fontWeight="500"
                    textAnchor="middle"
                    className="select-none pointer-events-none drop-shadow"
                  >
                    {node.label.length > 20 ? node.label.slice(0, 18) + '...' : node.label}
                  </text>
                </g>
              );
            })}
          </svg>

          {/* Canvas Legend */}
          <div className="absolute bottom-4 left-4 bg-[#111827]/90 backdrop-blur-md p-3 rounded-xl border border-gray-800 text-xs space-y-2">
            <span className="text-[10px] text-gray-400 font-bold uppercase tracking-wider block">Legend</span>
            <div className="flex items-center gap-4 text-gray-300">
              <span className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-full bg-blue-500" /> Concept</span>
              <span className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-full bg-purple-500" /> Claim</span>
              <span className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-full bg-emerald-500" /> Method</span>
              <span className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-full bg-amber-500" /> Conflicted</span>
            </div>
            <div className="flex items-center gap-4 text-gray-400 text-[11px] pt-1 border-t border-gray-800">
              <span className="text-emerald-400 font-mono">── supports</span>
              <span className="text-red-400 font-mono">╌╌ contradicts</span>
            </div>
          </div>
        </div>
      </div>

      {/* Right Node Detail Inspector Sidebar */}
      <div className="w-96 bg-[#111827] border-l border-gray-800 flex flex-col shrink-0 overflow-y-auto p-6 space-y-6">
        <div>
          <h3 className="text-sm font-bold text-white uppercase tracking-wider flex items-center gap-2">
            <Info className="w-4 h-4 text-blue-400" />
            <span>Entity Inspector</span>
          </h3>
          <p className="text-xs text-gray-400 mt-1">
            Epistemic state, grounding evidence, and relation neighborhood.
          </p>
        </div>

        {selectedNode ? (
          <div className="space-y-5">
            {/* Header / Type */}
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-xs uppercase font-mono px-2 py-0.5 rounded bg-gray-800 text-gray-400">
                  {selectedNode.type}
                </span>
                <EpistemicBadge state={selectedNode.epistemic_state} />
              </div>
              <h4 className="text-base font-bold text-white leading-snug break-words">
                {selectedNode.label}
              </h4>
            </div>

            {/* Description / Wording */}
            <div className="space-y-1.5 bg-[#0B0F19] p-3.5 rounded-xl border border-gray-800">
              <span className="text-[10px] text-gray-500 font-bold uppercase tracking-wider block">Description / Wording:</span>
              <p className="text-xs text-gray-200 leading-relaxed italic">
                "{selectedNode.description}"
              </p>
            </div>

            {/* Evidence Linkage */}
            {selectedNode.evidence_id && (
              <div className="space-y-2 p-3 bg-emerald-950/20 border border-emerald-800/40 rounded-xl">
                <div className="flex items-center gap-1.5 text-emerald-400 text-xs font-semibold">
                  <ShieldCheck className="w-4 h-4" />
                  <span>Verifiable Evidence Link</span>
                </div>
                <div className="text-[11px] font-mono text-gray-300 break-all">
                  Evidence ID: {selectedNode.evidence_id}
                </div>
              </div>
            )}

            {/* Connected Relations in Graph */}
            <div className="space-y-2 pt-2 border-t border-gray-800">
              <span className="text-xs font-semibold text-gray-300 uppercase tracking-wider block">
                Connected Relations
              </span>
              {graphData.edges.filter(e => e.source === selectedNode.id || e.target === selectedNode.id).length === 0 ? (
                <div className="text-xs text-gray-500">No relations currently linked to this node.</div>
              ) : (
                <div className="space-y-2">
                  {graphData.edges
                    .filter(e => e.source === selectedNode.id || e.target === selectedNode.id)
                    .map((e) => {
                      const isSource = e.source === selectedNode.id;
                      const otherId = isSource ? e.target : e.source;
                      const otherNode = graphData.nodes.find(n => n.id === otherId);

                      return (
                        <div key={e.id} className="p-2.5 rounded-lg bg-[#1F2937] border border-gray-700 text-xs flex items-center justify-between">
                          <div className="flex items-center gap-2">
                            <ArrowRight className="w-3.5 h-3.5 text-blue-400" />
                            <span className="font-mono text-blue-300 font-semibold">{e.relation_type}</span>
                            <span className="text-gray-300 truncate max-w-[120px]">{otherNode?.label || otherId}</span>
                          </div>
                          {e.relation_type === 'contradicts' && (
                            <AlertTriangle className="w-3.5 h-3.5 text-red-400" />
                          )}
                        </div>
                      );
                    })}
                </div>
              )}
            </div>
          </div>
        ) : (
          <div className="text-center py-12 text-xs text-gray-500 border border-dashed border-gray-800 rounded-xl p-4">
            Click on any graph node to inspect its epistemic properties and evidence.
          </div>
        )}
      </div>
    </div>
  );
};
