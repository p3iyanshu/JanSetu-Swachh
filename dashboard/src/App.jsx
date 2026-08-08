import React, { useEffect, useMemo, useState } from 'react';
import {
  Bell,
  Camera,
  CheckCircle2,
  Clock,
  LogOut,
  MapPin,
  ShieldCheck,
  UserMinus,
  UserPlus,
  Users,
  Verified,
  XCircle,
} from 'lucide-react';
import { api, resolveMediaUrl } from './api/client';

const statusLabel = {
  submitted: 'Submitted',
  assigned: 'Assigned to Dept',
  in_progress: 'In Progress',
  pending_approval: 'Pending Admin Approval',
  resolved: 'Resolved',
  reopened: 'Reopened',
};

const categoryLabel = {
  pothole: 'Pothole',
  garbage_overflow: 'Garbage Overflow',
  broken_streetlight: 'Streetlight / Electricity',
  water_leakage: 'Water Leakage',
  sewage_overflow: 'Sewage Overflow',
  illegal_dumping: 'Illegal Dumping',
  damaged_public_property: 'Public Property Damage',
  other: 'Other',
};

function formatDate(value) {
  if (!value) return 'Not set';
  return new Date(value).toLocaleString();
}

function LoginScreen({ onLogin }) {
  const [mode, setMode] = useState('login');
  const [form, setForm] = useState({
    name: '',
    emp_id: '',
    password: '',
    contact: '',
  });
  const [error, setError] = useState('');

  async function submit(event) {
    event.preventDefault();
    setError('');
    try {
      const officer = mode === 'login' ? await api.login(form) : await api.signup(form);
      onLogin(officer);
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <main className="login-shell">
      <form className="login-panel" onSubmit={submit}>
        <div className="brand-mark">
          <ShieldCheck size={40} />
        </div>
        <h1>JanSetu</h1>
        <p>Admin</p>

        <div className="segmented">
          <button type="button" className={mode === 'login' ? 'active' : ''} onClick={() => setMode('login')}>
            Sign In
          </button>
          <button type="button" className={mode === 'signup' ? 'active' : ''} onClick={() => setMode('signup')}>
            Signup
          </button>
        </div>

        {mode === 'signup' && (
          <>
            <label>
              Admin Name
              <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
            </label>
            <label>
              Contact
              <input value={form.contact} onChange={(e) => setForm({ ...form, contact: e.target.value })} />
            </label>
          </>
        )}

        <label>
          Admin ID
          <input value={form.emp_id} onChange={(e) => setForm({ ...form, emp_id: e.target.value })} required />
        </label>
        <label>
          Password
          <input type="password" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} required />
        </label>

        {error && <div className="error">{error}</div>}
        <button className="primary" type="submit">
          {mode === 'login' ? 'SIGN IN' : 'REGISTER'}
        </button>
      </form>
    </main>
  );
}

function AssignWorkerControl({ ticket, onAssign }) {
  const [eligible, setEligible] = useState(null);
  const [officerId, setOfficerId] = useState('');
  const [hours, setHours] = useState(24);
  const [assigning, setAssigning] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    let cancelled = false;
    setEligible(null);
    setError('');
    api
      .eligibleWorkers(ticket.id)
      .then((data) => {
        if (!cancelled) setEligible(data);
      })
      .catch((err) => {
        if (!cancelled) {
          setEligible({ workers: [] });
          setError(err.message);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [ticket.id]);

  async function handleAssign() {
    setAssigning(true);
    setError('');
    try {
      await onAssign(ticket.id, Number(officerId), Number(hours));
      setOfficerId('');
    } catch (err) {
      setError(err.message);
    } finally {
      setAssigning(false);
    }
  }

  if (eligible === null) {
    return (
      <div className="inline-controls">
        <span>Loading eligible workers...</span>
      </div>
    );
  }

  return (
    <div className="assign-block">
      <div className="inline-controls">
        <select
          value={officerId}
          onChange={(e) => setOfficerId(e.target.value)}
          disabled={eligible.workers.length === 0}
        >
          <option value="">
            {eligible.workers.length === 0 ? 'No eligible workers available' : 'Select eligible worker'}
          </option>
          {eligible.workers.map((worker) => (
            <option key={worker.id} value={worker.id}>
              {worker.name} ({worker.emp_id || 'no ID'}) - {worker.active_ticket_count}/{worker.capacity} active
            </option>
          ))}
        </select>
        <label className="hours-field">
          Resolution Time (hrs)
          <input type="number" min="1" value={hours} onChange={(e) => setHours(e.target.value)} />
        </label>
        <button type="button" onClick={handleAssign} disabled={!officerId || assigning}>
          {assigning ? 'Assigning...' : 'Assign'}
        </button>
      </div>
      {error && <div className="error">{error}</div>}
    </div>
  );
}

function PendingApprovalReview({ ticket, onApprove, onReject }) {
  const [comment, setComment] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  async function handle(action) {
    setBusy(true);
    setError('');
    try {
      await action(ticket.id, comment.trim() || undefined);
      setComment('');
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="review-block">
      <div className="review-header">
        <ShieldCheck size={16} />
        <span>Worker submitted proof - review before it goes to the citizen</span>
      </div>
      {ticket.latest_resolution_photo_url && (
        <a
          className="proof-photo-link"
          href={resolveMediaUrl(ticket.latest_resolution_photo_url)}
          target="_blank"
          rel="noreferrer"
        >
          <img src={resolveMediaUrl(ticket.latest_resolution_photo_url)} alt="Submitted proof" />
          View Submitted Proof Photo
        </a>
      )}
      {ticket.latest_resolution_captured_at && (
        <span className="review-meta">Captured: {formatDate(ticket.latest_resolution_captured_at)}</span>
      )}
      <textarea
        placeholder="Optional note (required-ish if rejecting, so the worker knows why)"
        value={comment}
        onChange={(e) => setComment(e.target.value)}
        rows={2}
      />
      <div className="inline-controls review-actions">
        <button type="button" className="approve-btn" onClick={() => handle(onApprove)} disabled={busy}>
          <CheckCircle2 size={16} /> Approve & Notify Citizen
        </button>
        <button type="button" className="reject-btn" onClick={() => handle(onReject)} disabled={busy}>
          <XCircle size={16} /> Reject - Send Back to Worker
        </button>
      </div>
      {error && <div className="error">{error}</div>}
    </div>
  );
}

function TicketCard({ ticket, currentOfficer, onAssign, onStart, onResolve, onApprove, onReject }) {
  const [file, setFile] = useState(null);

  function resolveTicket() {
    if (!file) return;
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const formData = new FormData();
        formData.append('officer_id', currentOfficer.id);
        formData.append('latitude', position.coords.latitude);
        formData.append('longitude', position.coords.longitude);
        formData.append('after_photo', file);
        onResolve(ticket.id, formData);
      },
      () => alert('GPS permission is required to close a ticket.'),
      { enableHighAccuracy: true },
    );
  }

  return (
    <article className="ticket-card">
      <div className="ticket-top">
        <div>
          <strong>JAN-{String(ticket.id).padStart(6, '0')}</strong>
          <span>{categoryLabel[ticket.category] || ticket.category}</span>
        </div>
        <span className={`badge badge-${ticket.status}`}>{statusLabel[ticket.status] || ticket.status}</span>
      </div>
      <p>{ticket.description || 'No description provided.'}</p>
      <div className="ticket-meta">
        <span><MapPin size={14} /> {ticket.latitude.toFixed(4)}, {ticket.longitude.toFixed(4)}</span>
        <span><Clock size={14} /> Created {formatDate(ticket.created_at)}</span>
        <span>Priority {Math.round(ticket.priority_score)}</span>
        <span>Dept: {ticket.assigned_department_name || 'Pending routing'}</span>
        <span>
          Worker: {ticket.assigned_officer_name
            ? `${ticket.assigned_officer_name} (${ticket.assigned_officer_emp_id || 'no ID'})`
            : 'Not assigned'}
        </span>
        <span>ETA: {formatDate(ticket.estimated_completion_at)}</span>
      </div>

      {ticket.status !== 'resolved' && !ticket.assigned_officer_id && (
        <AssignWorkerControl ticket={ticket} onAssign={onAssign} />
      )}

      {ticket.status === 'assigned' && ticket.assigned_officer_id === currentOfficer.id && (
        <div className="resolve-row">
          <span>Officer assigned - work not started yet</span>
          <button type="button" onClick={() => onStart(ticket.id, currentOfficer.id)}>
            Start Work
          </button>
        </div>
      )}

      {ticket.status === 'in_progress' && ticket.assigned_officer_id === currentOfficer.id && (
        <div className="resolve-row">
          <label className="camera-button">
            <Camera size={18} />
            Capture Geo-tag Proof
            <input
              type="file"
              accept="image/*"
              capture="environment"
              onChange={(e) => setFile(e.target.files?.[0] || null)}
            />
          </label>
          <span>{file ? file.name : 'Camera capture required'}</span>
          <button type="button" onClick={resolveTicket} disabled={!file}>
            Close Ticket
          </button>
        </div>
      )}

      {ticket.status === 'pending_approval' && (
        <PendingApprovalReview ticket={ticket} onApprove={onApprove} onReject={onReject} />
      )}

      {ticket.status === 'resolved' && !ticket.citizen_verified && (
        <div className="resolved-box awaiting">
          <CheckCircle2 size={18} />
          <span>
            Approved by admin on {formatDate(ticket.resolved_at)} - waiting for the citizen to confirm they're satisfied.
          </span>
          {ticket.latest_resolution_photo_url && (
            <a
              className="proof-photo-link"
              href={resolveMediaUrl(ticket.latest_resolution_photo_url)}
              target="_blank"
              rel="noreferrer"
            >
              <img src={resolveMediaUrl(ticket.latest_resolution_photo_url)} alt="Resolution proof" />
              View Proof Photo
            </a>
          )}
        </div>
      )}

      {ticket.status === 'resolved' && ticket.citizen_verified && (
        <div className="resolved-box verified">
          <Verified size={18} />
          <span>
            Ticket fully closed - citizen confirmed they're satisfied.
            {ticket.citizen_feedback_comment ? ` "${ticket.citizen_feedback_comment}"` : ''}
          </span>
          {ticket.latest_resolution_photo_url && (
            <a
              className="proof-photo-link"
              href={resolveMediaUrl(ticket.latest_resolution_photo_url)}
              target="_blank"
              rel="noreferrer"
            >
              <img src={resolveMediaUrl(ticket.latest_resolution_photo_url)} alt="Resolution proof" />
              View Proof Photo
            </a>
          )}
        </div>
      )}

      {ticket.status === 'reopened' && (
        <div className="resolved-box reopened">
          <XCircle size={18} />
          <span>
            Citizen was not satisfied and reopened this ticket.
            {ticket.citizen_feedback_comment ? ` "${ticket.citizen_feedback_comment}"` : ''}
          </span>
        </div>
      )}

      {ticket.admin_review_comment && ticket.status === 'in_progress' && (
        <div className="resolved-box rejected">
          <XCircle size={18} />
          <span>Admin sent this back for rework: "{ticket.admin_review_comment}"</span>
        </div>
      )}
    </article>
  );
}

export default function App() {
  const [departments, setDepartments] = useState([]);
  const [reports, setReports] = useState([]);
  const [officers, setOfficers] = useState([]);
  const [allOfficers, setAllOfficers] = useState([]);
  const [me, setMe] = useState(() => {
    const stored = localStorage.getItem('jansetu_admin_user');
    return stored ? JSON.parse(stored) : null;
  });
  const [statusFilter, setStatusFilter] = useState('all');
  const [departmentFilter, setDepartmentFilter] = useState('all');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [assignmentFilter, setAssignmentFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [showActionableOnly, setShowActionableOnly] = useState(false);

  async function loadData() {
    const [departmentData, reportData, allOfficersData] = await Promise.all([
      api.departments(),
      api.reports(),
      api.officers(),
    ]);
    setDepartments(departmentData);
    setReports(reportData);
    setAllOfficers(allOfficersData);
    if (me) {
      setOfficers(await api.officers(me.department_id));
    }
  }

  useEffect(() => {
    loadData().catch(console.warn);
    const interval = setInterval(() => loadData().catch(console.warn), 5000);
    return () => clearInterval(interval);
  }, [me?.id]);

  // "Needs attention" = things sitting in the admin's court right now: brand
  // new tickets, tickets routed to a department but with no worker picked
  // yet, and worker submissions awaiting approval. This self-clears the
  // moment the admin acts (assigns a worker / approves a ticket) - it's a
  // live count, not a dismissible unread log.
  const actionableReports = useMemo(() => {
    return reports.filter(
      (report) =>
        report.status === 'submitted' ||
        (report.status === 'assigned' && !report.assigned_officer_id) ||
        report.status === 'pending_approval',
    );
  }, [reports]);

  const filteredReports = useMemo(() => {
    const source = showActionableOnly ? actionableReports : reports;
    const needle = search.trim().toLowerCase();
    return source.filter((report) => {
      if (statusFilter !== 'all' && report.status !== statusFilter) return false;
      if (departmentFilter !== 'all' && String(report.assigned_department_id) !== departmentFilter) return false;
      if (categoryFilter !== 'all' && report.category !== categoryFilter) return false;
      if (assignmentFilter === 'assigned' && !report.assigned_officer_id) return false;
      if (assignmentFilter === 'unassigned' && report.assigned_officer_id) return false;
      if (needle) {
        const ticketIdText = `jan-${String(report.id).padStart(6, '0')}`;
        const haystack = `${ticketIdText} ${report.description || ''}`.toLowerCase();
        if (!haystack.includes(needle)) return false;
      }
      return true;
    });
  }, [reports, actionableReports, showActionableOnly, statusFilter, departmentFilter, categoryFilter, assignmentFilter, search]);

  function handleLogin(officer) {
    localStorage.setItem('jansetu_admin_user', JSON.stringify(officer));
    setMe(officer);
  }

  async function assign(reportId, officerId, estimatedHours) {
    await api.assign(reportId, { officer_id: officerId, estimated_hours: estimatedHours });
    await loadData();
  }

  async function startWork(reportId, officerId) {
    await api.startWork(reportId, officerId);
    await loadData();
  }

  async function resolve(reportId, formData) {
    await api.resolve(reportId, formData);
    await loadData();
  }

  async function approve(reportId, comment) {
    await api.approve(reportId, comment);
    await loadData();
  }

  async function reject(reportId, comment) {
    await api.reject(reportId, comment);
    await loadData();
  }

  async function removeOfficer(officerId) {
    await api.removeOfficer(officerId);
    await loadData();
  }

  if (!me) {
    return <LoginScreen onLogin={handleLogin} />;
  }

  return (
    <main className="admin-shell">
      <header className="admin-header">
        <div>
          <h1>JanSetu Admin</h1>
          <p>
            {me.name} · {departments.find((department) => department.id === me.department_id)?.name || 'Platform Admin'} · All Tickets
          </p>
        </div>
        <button
          className={`notification ${actionableReports.length > 0 ? 'has-alerts' : ''} ${showActionableOnly ? 'active' : ''}`}
          type="button"
          onClick={() => setShowActionableOnly((value) => !value)}
          title="Tickets needing your attention: new, unassigned, or awaiting your approval"
        >
          <span className="bell-wrap">
            <Bell size={18} />
            {actionableReports.length > 0 && <span className="notification-badge">{actionableReports.length}</span>}
          </span>
          {showActionableOnly ? 'Showing needs-attention only' : 'Needs Attention'}
        </button>
        <button
          className="ghost"
          type="button"
          onClick={() => {
            localStorage.removeItem('jansetu_admin_user');
            setMe(null);
          }}
        >
          <LogOut size={18} />
          Logout
        </button>
      </header>

      <section className="metrics-grid">
        <div><strong>{reports.filter((r) => r.status === 'assigned').length}</strong><span>Dept Queue</span></div>
        <div><strong>{reports.filter((r) => r.status === 'in_progress').length}</strong><span>In Progress</span></div>
        <div><strong>{reports.filter((r) => r.status === 'pending_approval').length}</strong><span>Pending Approval</span></div>
        <div><strong>{reports.filter((r) => r.status === 'resolved' && r.citizen_verified).length}</strong><span>Fully Closed</span></div>
      </section>

      <section className="dept-free-workers-grid">
        {departments.map((department) => {
          const deptOfficers = allOfficers.filter((officer) => officer.department_id === department.id);
          const free = deptOfficers.filter((officer) => officer.is_available).length;
          return (
            <div key={department.id} className="dept-free-workers-card">
              <span className="dept-free-workers-name">{department.name}</span>
              <strong>{free}</strong>
              <span className="dept-free-workers-total">free of {deptOfficers.length}</span>
            </div>
          );
        })}
      </section>

      {me.is_department_head && (
        <section className="worker-panel">
          <h2><Users size={20} /> Department Workers</h2>
          <div className="worker-list">
            {officers.map((officer) => (
              <div key={officer.id} className="worker-row">
                <span>{officer.name} ({officer.emp_id})</span>
                <b>{officer.is_available ? 'Free' : 'Busy'}</b>
                {!officer.is_department_head && (
                  <button type="button" onClick={() => removeOfficer(officer.id)}>
                    <UserMinus size={16} /> Remove
                  </button>
                )}
              </div>
            ))}
          </div>
          <p><UserPlus size={16} /> New employees use First Signup, then the department head can assign or remove them here.</p>
        </section>
      )}

      <section className="filters-bar">
        <input
          placeholder="Search ticket ID or description"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
          <option value="all">All statuses</option>
          <option value="submitted">Submitted</option>
          <option value="assigned">Assigned</option>
          <option value="in_progress">In Progress</option>
          <option value="pending_approval">Pending Admin Approval</option>
          <option value="resolved">Resolved</option>
          <option value="reopened">Reopened</option>
        </select>
        <select value={departmentFilter} onChange={(e) => setDepartmentFilter(e.target.value)}>
          <option value="all">All departments</option>
          {departments.map((department) => (
            <option key={department.id} value={String(department.id)}>
              {department.name}
            </option>
          ))}
        </select>
        <select value={categoryFilter} onChange={(e) => setCategoryFilter(e.target.value)}>
          <option value="all">All categories</option>
          {Object.entries(categoryLabel).map(([value, label]) => (
            <option key={value} value={value}>
              {label}
            </option>
          ))}
        </select>
        <select value={assignmentFilter} onChange={(e) => setAssignmentFilter(e.target.value)}>
          <option value="all">Assigned + unassigned</option>
          <option value="unassigned">Unassigned only</option>
          <option value="assigned">Assigned only</option>
        </select>
        <span className="filters-count">
          {filteredReports.length} of {reports.length} tickets
        </span>
      </section>

      <section className="ticket-list">
        {filteredReports.map((ticket) => (
          <TicketCard
            key={ticket.id}
            ticket={ticket}
            currentOfficer={me}
            onAssign={assign}
            onStart={startWork}
            onResolve={resolve}
            onApprove={approve}
            onReject={reject}
          />
        ))}
        {filteredReports.length === 0 && (
          <p className="empty-state">No tickets match the current filters.</p>
        )}
      </section>
    </main>
  );
}
