import React from 'react';
import { EpistemicState } from '../types';
import { ShieldCheck, Sparkles, UserCheck, AlertTriangle, HelpCircle } from 'lucide-react';

interface EpistemicBadgeProps {
  state: EpistemicState;
  size?: 'sm' | 'md';
  showIcon?: boolean;
}

export const EpistemicBadge: React.FC<EpistemicBadgeProps> = ({ 
  state, 
  size = 'md',
  showIcon = true 
}) => {
  const configs: Record<EpistemicState, { label: string; bg: string; text: string; border: string; icon: React.ReactNode }> = {
    source_grounded: {
      label: 'Source Grounded',
      bg: 'bg-emerald-950/40',
      text: 'text-emerald-400',
      border: 'border-emerald-600/40',
      icon: <ShieldCheck className="w-3.5 h-3.5" />
    },
    human_reviewed: {
      label: 'Human Reviewed',
      bg: 'bg-blue-950/40',
      text: 'text-blue-400',
      border: 'border-blue-600/40',
      icon: <UserCheck className="w-3.5 h-3.5" />
    },
    ai_inferred: {
      label: 'AI Inferred (Staged)',
      bg: 'bg-purple-950/40',
      text: 'text-purple-400',
      border: 'border-purple-600/40',
      icon: <Sparkles className="w-3.5 h-3.5" />
    },
    conflicted: {
      label: 'Conflicted',
      bg: 'bg-amber-950/40',
      text: 'text-amber-400',
      border: 'border-amber-600/40',
      icon: <AlertTriangle className="w-3.5 h-3.5" />
    },
    insufficient_evidence: {
      label: 'Insufficient Evidence',
      bg: 'bg-slate-900/60',
      text: 'text-slate-400',
      border: 'border-slate-700/40',
      icon: <HelpCircle className="w-3.5 h-3.5" />
    }
  };

  const config = configs[state] || configs.insufficient_evidence;
  const sizeClasses = size === 'sm' ? 'px-1.5 py-0.5 text-xs' : 'px-2.5 py-1 text-xs font-medium';

  return (
    <span className={`inline-flex items-center gap-1.5 rounded-full border ${config.bg} ${config.text} ${config.border} ${sizeClasses}`}>
      {showIcon && config.icon}
      <span>{config.label}</span>
    </span>
  );
};
