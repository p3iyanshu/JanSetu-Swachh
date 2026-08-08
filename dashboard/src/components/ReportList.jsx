import React from 'react';
import { updateReportStatus } from '../api/client';

export default function ReportList({ reports, onRefresh }) {
  const handleStatusChange = async (reportId, newStatus) => {
    await updateReportStatus(reportId, newStatus);
    if (onRefresh) onRefresh();
  };

  return (
    <div className="glass-card" style={{ padding: '20px', marginTop: '24px' }}>
      <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '16px' }}>Active Civic Tickets (Live Stream)</h2>
      <div style={{ overflowX: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '0.9rem' }}>
          <thead>
            <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.1)', color: '#94a3b8' }}>
              <th style={{ padding: '12px' }}>Ticket ID</th>
              <th style={{ padding: '12px' }}>Category</th>
              <th style={{ padding: '12px' }}>Description</th>
              <th style={{ padding: '12px' }}>Priority</th>
              <th style={{ padding: '12px' }}>Upvotes</th>
              <th style={{ padding: '12px' }}>Status</th>
              <th style={{ padding: '12px' }}>Action</th>
            </tr>
          </thead>
          <tbody>
            {reports.map((r) => (
              <tr key={r.id} style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                <td style={{ padding: '12px', fontWeight: 600 }}>#{r.id}</td>
                <td style={{ padding: '12px', textTransform: 'capitalize' }}>{r.category.replace('_', ' ')}</td>
                <td style={{ padding: '12px', color: '#cbd5e1', maxWidth: '280px' }}>{r.description}</td>
                <td style={{ padding: '12px', fontWeight: 700, color: r.priority_score > 90 ? '#ef4444' : '#f97316' }}>
                  {r.priority_score}
                </td>
                <td style={{ padding: '12px' }}>{r.upvote_count} citizens</td>
                <td style={{ padding: '12px' }}>
                  <span className={`badge badge-${r.status}`}>{r.status.replace('_', ' ')}</span>
                </td>
                <td style={{ padding: '12px' }}>
                  <select
                    value={r.status}
                    onChange={(e) => handleStatusChange(r.id, e.target.value)}
                    style={{ background: '#1e293b', color: '#fff', border: '1px solid #475569', borderRadius: '6px', padding: '4px 8px' }}
                  >
                    <option value="submitted">Submitted</option>
                    <option value="assigned">Assigned</option>
                    <option value="in_progress">In Progress</option>
                    <option value="resolved">Resolved</option>
                    <option value="reopened">Reopened</option>
                  </select>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
