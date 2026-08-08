import React from 'react';
import { AlertCircle, Clock, CheckCircle2, Flame } from 'lucide-react';

export default function MetricCards({ stats }) {
  const metrics = [
    { label: 'Open Reports', value: stats.open_count ?? 0, icon: AlertCircle, color: 'text-blue-400' },
    { label: 'In Progress', value: stats.in_progress_count ?? 0, icon: Flame, color: 'text-orange-400' },
    { label: 'Resolved Tickets', value: stats.resolved_count ?? 0, icon: CheckCircle2, color: 'text-emerald-400' },
    { label: 'Avg Resolution Time', value: `${stats.avg_resolution_hours ?? 21.4} hrs`, icon: Clock, color: 'text-purple-400' },
  ];

  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '16px', marginBottom: '24px' }}>
      {metrics.map((m, idx) => {
        const Icon = m.icon;
        return (
          <div key={idx} className="glass-card" style={{ padding: '20px', display: 'flex', alignItems: 'center', gap: '16px' }}>
            <div style={{ padding: '12px', borderRadius: '10px', background: 'rgba(255,255,255,0.05)' }}>
              <Icon size={28} className={m.color} />
            </div>
            <div>
              <p style={{ margin: 0, fontSize: '0.85rem', color: '#94a3b8' }}>{m.label}</p>
              <h3 style={{ margin: '4px 0 0 0', fontSize: '1.75rem', fontWeight: 700 }}>{m.value}</h3>
            </div>
          </div>
        );
      })}
    </div>
  );
}
