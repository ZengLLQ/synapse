import React, { useState } from 'react';
import { ReviewItem } from '../types';
import { CheckSquare, Check, X, Sparkles, Filter, Clock } from 'lucide-react';

interface ReviewQueueViewProps {
  items: ReviewItem[];
  onDecideItem: (itemId: string, action: 'accept' | 'reject', notes: string) => Promise<void>;
  onRefresh: () => void;
}

export const ReviewQueueView: React.FC<ReviewQueueViewProps> = ({
  items,
  onDecideItem,
  onRefresh
}) => {
  const [selectedStatus, setSelectedStatus] = useState<string>('pending');
  const [decidingId, setDecidingId] = useState<string | null>(null);
  const [notes, setNotes] = useState<string>('Reviewed and confirmed by researcher.');

  const handleDecide = async (id: string, action: 'accept' | 'reject') => {
    setDecidingId(id);
    try {
      await onDecideItem(id, action, notes);
      onRefresh();
    } catch (err: any) {
      alert(`Review decision failed: ${err.message}`);
    } finally {
      setDecidingId(null);
    }
  };

  const filteredItems = items.filter(i => selectedStatus === 'all' || i.status === selectedStatus);

  return (
    <div className="p-8 max-w-5xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2.5">
            <CheckSquare className="w-6 h-6 text-purple-400" />
            <span>Accountable Review Queue</span>
          </h1>
          <p className="text-sm text-gray-400 mt-1">
            Stage AI-inferred entities and relations. Human review transitions candidates into verified knowledge.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <div className="flex items-center gap-1.5 bg-[#1F2937] border border-gray-700 rounded-lg px-3 py-1.5 text-xs text-gray-300">
            <Filter className="w-3.5 h-3.5 text-gray-400" />
            <select
              value={selectedStatus}
              onChange={(e) => setSelectedStatus(e.target.value)}
              className="bg-transparent focus:outline-none"
            >
              <option value="pending">Pending Review</option>
              <option value="accepted">Accepted</option>
              <option value="rejected">Rejected</option>
              <option value="all">All Items</option>
            </select>
          </div>

          <button
            onClick={onRefresh}
            className="text-xs bg-gray-800 hover:bg-gray-700 text-gray-300 px-3 py-1.5 rounded-lg border border-gray-700 transition-colors"
          >
            Refresh
          </button>
        </div>
      </div>

      {/* Review Items List */}
      {filteredItems.length === 0 ? (
        <div className="text-center py-20 bg-[#111827] rounded-2xl border border-gray-800 p-8 space-y-3">
          <CheckSquare className="w-12 h-12 text-gray-600 mx-auto" />
          <h3 className="text-base font-medium text-gray-200">Review Queue Empty</h3>
          <p className="text-sm text-gray-400 max-w-md mx-auto">
            No items matching the selected status ({selectedStatus}). Newly ingested documents will populate candidates here.
          </p>
        </div>
      ) : (
        <div className="space-y-4">
          {filteredItems.map((item) => {
            const isProcessing = decidingId === item.id;

            return (
              <div
                key={item.id}
                className="bg-[#111827] rounded-2xl border border-gray-800 p-5 space-y-4 shadow-xl hover:border-gray-700 transition-all"
              >
                <div className="flex items-start justify-between">
                  <div className="flex items-center gap-3">
                    <span className="text-xs font-mono uppercase bg-purple-950/60 text-purple-300 border border-purple-800/40 px-2.5 py-1 rounded-md">
                      {item.entity_type}
                    </span>
                    <span className="text-xs text-gray-400 font-mono">
                      Target ID: {item.entity_id}
                    </span>
                  </div>

                  <div className="flex items-center gap-3">
                    <div className="flex items-center gap-1.5 text-xs text-blue-400 bg-blue-950/40 border border-blue-800/30 px-2.5 py-0.5 rounded-full font-mono">
                      <Sparkles className="w-3.5 h-3.5" />
                      <span>{(item.confidence * 100).toFixed(0)}% Confidence</span>
                    </div>

                    <span className={`text-xs px-2.5 py-0.5 rounded-full font-semibold ${
                      item.status === 'accepted' 
                        ? 'bg-emerald-950/60 text-emerald-400 border border-emerald-500/30'
                        : item.status === 'rejected'
                        ? 'bg-red-950/60 text-red-400 border border-red-500/30'
                        : 'bg-amber-950/60 text-amber-400 border border-amber-500/30'
                    }`}>
                      {item.status.toUpperCase()}
                    </span>
                  </div>
                </div>

                <div className="bg-[#0B0F19] p-3.5 rounded-xl border border-gray-800 text-xs text-gray-300 leading-relaxed">
                  <span className="text-[10px] text-gray-500 font-bold uppercase tracking-wider block mb-1">Model Rationale:</span>
                  {item.rationale}
                </div>

                {item.status === 'pending' && (
                  <div className="pt-3 border-t border-gray-800 space-y-2">
                    <div className="flex items-center gap-2">
                      <span className="text-[11px] text-gray-400">Review Note:</span>
                      <input
                        type="text"
                        value={notes}
                        onChange={(e) => setNotes(e.target.value)}
                        placeholder="Rationale for accept/reject..."
                        className="flex-1 bg-[#0B0F19] border border-gray-700 rounded px-2 py-1 text-xs text-white"
                      />
                    </div>

                    <div className="flex items-center justify-between">
                      <div className="text-[11px] text-gray-500 flex items-center gap-1.5">
                        <Clock className="w-3.5 h-3.5" />
                        <span>Staged: {new Date(item.created_at).toLocaleString()}</span>
                      </div>

                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => handleDecide(item.id, 'reject')}
                          disabled={isProcessing}
                          className="inline-flex items-center gap-1.5 text-xs font-semibold px-3 py-1.5 rounded-lg bg-red-950/40 hover:bg-red-900/60 text-red-300 border border-red-800/40 transition-colors"
                        >
                          <X className="w-3.5 h-3.5" />
                          <span>Reject</span>
                        </button>

                        <button
                          onClick={() => handleDecide(item.id, 'accept')}
                          disabled={isProcessing}
                          className="inline-flex items-center gap-1.5 text-xs font-semibold px-4 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white shadow-md shadow-emerald-600/20 transition-colors"
                        >
                          <Check className="w-3.5 h-3.5" />
                          <span>Accept & Promote</span>
                        </button>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
