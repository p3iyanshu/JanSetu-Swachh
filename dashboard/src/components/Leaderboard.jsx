import React from 'react';
import { Award, ShieldAlert, RotateCcw } from 'lucide-react';

export default function Leaderboard({ departments }) {
  return (
    <div className="glass-card" style={{ padding: '20px', marginTop: '24px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '16px' }}>
        <Award className="text-yellow-400" size={24} />
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, margin: 0 }}>Public Department Accountability Leaderboard</h2>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '16px' }}>
        {departments.map((dept, idx) => (
          <div key={dept.id} style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: '10px', padding: '16px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: '0.8rem', fontWeight: 700, color: '#facc15' }}>#{idx + 1} RANK</span>
              <span style={{ fontSize: '0.85rem', color: '#94a3b8' }}>{dept.avg_resolution_time}h avg speed</span>
            </div>
            <h4 style={{ margin: '8px 0 12px 0', fontSize: '1.05rem' }}>{dept.name}</h4>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem', color: '#cbd5e1' }}>
              <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                <ShieldAlert size={14} className="text-red-400" /> SLA Breach: <strong>{dept.sla_breach_rate}%</strong>
              </span>
              <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                <RotateCcw size={14} className="text-orange-400" /> Reopen: <strong>{dept.reopen_rate}%</strong>
              </span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
