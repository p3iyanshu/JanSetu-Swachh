import React, { useEffect, useState } from 'react';
import { Award, ClipboardList, Home, PlusCircle, Recycle } from 'lucide-react';
import { api } from '../api/client';
import PortalShell from '../components/PortalShell';
import { CITIZEN_CATEGORIES } from '../lib/categories';
import MyTickets from './MyTickets';
import ReportIssue from './ReportIssue';
import WasteGuide from './WasteGuide';

function ImpactCard({ impact }) {
  if (!impact) return null;
  const next = impact.next_level;
  const progress = next ? impact.points / (impact.points + next.points_needed) : 1;
  return (
    <section className="impact-card">
      <div className="impact-top">
        <Award size={30} />
        <div>
          <strong>{impact.level}</strong>
          <span>{next ? `${next.points_needed} points to ${next.name}` : 'Top level reached - thank you!'}</span>
        </div>
        <div className="impact-points">
          <b>{impact.points}</b>
          <span>Swachh points</span>
        </div>
      </div>
      <div className="impact-bar"><span style={{ width: `${Math.min(100, progress * 100)}%` }} /></div>
      <div className="impact-stats">
        <div><b>{impact.reports_filed}</b><span>Reported</span></div>
        <div><b>{impact.resolved}</b><span>Fixed</span></div>
        <div><b>{impact.verified}</b><span>Verified by you</span></div>
      </div>
    </section>
  );
}

function CitizenHome({ impact, onQuickReport, onGuide }) {
  return (
    <div className="citizen-home">
      <section className="hero-card">
        <div>
          <h2>Namaste!</h2>
          <p>Spot it, snap it, get it cleaned - and track it till the job is verified.</p>
        </div>
        <button type="button" className="primary" onClick={() => onQuickReport('')}>
          <PlusCircle size={18} /> Report an issue
        </button>
      </section>

      <ImpactCard impact={impact} />

      <section className="portal-panel">
        <h3 className="panel-title">Swachh quick report</h3>
        <div className="quick-grid">
          {CITIZEN_CATEGORIES.filter((item) => item.group === 'swachh').map((item) => (
            <button key={item.id} type="button" className="quick-tile" onClick={() => onQuickReport(item.id)}>
              <strong>{item.label}</strong>
              <span>{item.hint}</span>
            </button>
          ))}
        </div>
      </section>

      <button type="button" className="guide-banner" onClick={onGuide}>
        <Recycle size={30} />
        <div>
          <strong>Which Bin? Segregation guide</strong>
          <span>Wet, dry, sanitary or special care - search any household item.</span>
        </div>
      </button>
    </div>
  );
}

export default function CitizenApp({ user, onLogout }) {
  const [tab, setTab] = useState('home');
  const [reportCategory, setReportCategory] = useState('');
  const [tickets, setTickets] = useState([]);
  const [loadingTickets, setLoadingTickets] = useState(true);
  const [impact, setImpact] = useState(null);

  async function refresh() {
    try {
      const [mine, points] = await Promise.all([api.myReports(user.id), api.citizenImpact(user.id)]);
      setTickets(mine.sort((a, b) => b.id - a.id));
      setImpact(points);
    } catch (err) {
      console.warn(err);
    } finally {
      setLoadingTickets(false);
    }
  }

  useEffect(() => {
    refresh();
    const interval = setInterval(refresh, 10000);
    return () => clearInterval(interval);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user.id]);

  function openReport(category) {
    setReportCategory(category);
    setTab('report');
  }

  const openCount = tickets.filter((t) => !['resolved', 'cancelled'].includes(t.status)).length;

  return (
    <PortalShell
      title="JanSetu-Swachh"
      subtitle={`Citizen · +91 ${user.phone}`}
      roleLabel="Citizen"
      tabs={[
        { id: 'home', label: 'Home', icon: Home },
        { id: 'report', label: 'Report Issue', icon: PlusCircle },
        { id: 'tickets', label: 'My Tickets', icon: ClipboardList, count: openCount },
        { id: 'guide', label: 'Which Bin?', icon: Recycle },
      ]}
      activeTab={tab}
      onTabChange={(next) => {
        if (next === 'report') setReportCategory('');
        setTab(next);
      }}
      onLogout={onLogout}
    >
      {tab === 'home' && <CitizenHome impact={impact} onQuickReport={openReport} onGuide={() => setTab('guide')} />}
      {tab === 'report' && (
        <ReportIssue userId={user.id} initialCategory={reportCategory} onSubmitted={refresh} />
      )}
      {tab === 'tickets' && (
        <MyTickets tickets={tickets} loading={loadingTickets} onChanged={refresh} onReport={() => openReport('')} />
      )}
      {tab === 'guide' && <WasteGuide />}
    </PortalShell>
  );
}
