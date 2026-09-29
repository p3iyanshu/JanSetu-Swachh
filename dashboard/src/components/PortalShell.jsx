import React from 'react';
import { LogOut } from 'lucide-react';

/**
 * Header + section tabs shared by the citizen and worker portals, styled to
 * match the admin dashboard.
 */
export default function PortalShell({ title, subtitle, roleLabel, tabs, activeTab, onTabChange, onLogout, children }) {
  return (
    <main className="admin-shell portal-shell">
      <header className="portal-header">
        <div className="brand-mark">
          <img src="/indian-emblem.png" alt="Emblem of India" />
        </div>
        <div className="portal-header-text">
          <h1>{title}</h1>
          <p>{subtitle}</p>
        </div>
        <span className="role-badge">{roleLabel}</span>
        <button className="ghost" type="button" onClick={onLogout}>
          <LogOut size={18} />
          Logout
        </button>
      </header>

      <nav className="view-tabs" aria-label="Sections">
        {tabs.map(({ id, label, icon: Icon, count }) => (
          <button
            key={id}
            type="button"
            className={activeTab === id ? 'active' : ''}
            aria-pressed={activeTab === id}
            onClick={() => onTabChange(id)}
          >
            <Icon size={16} /> {label}
            {count ? <span className="tab-count">{count}</span> : null}
          </button>
        ))}
      </nav>

      {children}
    </main>
  );
}
