import React, { useEffect, useState } from 'react';
import { Building2, ClipboardCheck, Recycle } from 'lucide-react';
import { api } from '../api/client';
import PortalShell from '../components/PortalShell';
import CollectionRound from './CollectionRound';
import WorkerTicket from './WorkerTicket';

const ACTIVE = new Set(['assigned', 'in_progress', 'reopened', 'pending_approval']);

export default function WorkerApp({ user, onLogout }) {
  const [tab, setTab] = useState('mine');
  const [assigned, setAssigned] = useState([]);
  const [departmentTickets, setDepartmentTickets] = useState([]);
  const [department, setDepartment] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  async function refresh() {
    try {
      const [mine, deptTickets, departments] = await Promise.all([
        api.assignedTo(user.id),
        api.departmentReports(user.department_id),
        api.departments(),
      ]);
      setAssigned(mine);
      setDepartmentTickets(deptTickets);
      setDepartment(departments.find((item) => item.id === user.department_id) || null);
      setError('');
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    refresh();
    const interval = setInterval(refresh, 8000);
    return () => clearInterval(interval);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user.id]);

  const departmentName = department?.name || 'Department';
  const isSanitation = /waste|sanitation|garbage/i.test(departmentName) || !department;
  const activeMine = assigned.filter((ticket) => ACTIVE.has(ticket.status));
  const tickets = tab === 'mine' ? activeMine : departmentTickets;

  const tabs = [
    { id: 'mine', label: 'My Tickets', icon: ClipboardCheck, count: activeMine.length },
    { id: 'department', label: 'Department Tickets', icon: Building2 },
  ];
  if (isSanitation) tabs.push({ id: 'collection', label: 'Door-to-door Collection', icon: Recycle });

  return (
    <PortalShell
      title="JanSetu-Swachh Worker"
      subtitle={`${user.name} (${user.emp_id || '-'}) · ${departmentName}`}
      roleLabel="Worker"
      tabs={tabs}
      activeTab={tab}
      onTabChange={setTab}
      onLogout={onLogout}
    >
      {error && <div className="error">{error}</div>}
      {tab === 'collection' ? (
        <CollectionRound officer={user} />
      ) : (
        <section className="ticket-list">
          {loading && tickets.length === 0 && <p className="empty-state">Loading tickets...</p>}
          {!loading && tickets.length === 0 && (
            <p className="empty-state">
              {tab === 'mine'
                ? 'No active tickets assigned to you. An admin assigns tickets from the admin portal.'
                : 'No tickets for your department yet.'}
            </p>
          )}
          {tickets.map((ticket) => (
            <WorkerTicket key={ticket.id} ticket={ticket} officer={user} onChanged={refresh} />
          ))}
        </section>
      )}
    </PortalShell>
  );
}
