import React, { useState } from 'react';
import { CheckCircle2, Clock, MapPin, ThumbsDown, ThumbsUp, Verified, XCircle } from 'lucide-react';
import { api, resolveMediaUrl } from '../api/client';
import { categoryLabel } from '../lib/categories';
import { citizenStatusLabel, formatDate, ticketCode } from '../lib/format';

const CANCELLABLE = new Set(['submitted', 'assigned', 'in_progress', 'pending_approval', 'reopened']);

function Feedback({ ticket, onChanged }) {
  const [comment, setComment] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  async function send(satisfied) {
    setBusy(true);
    setError('');
    try {
      await api.feedback(ticket.id, satisfied, comment.trim());
      onChanged();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="feedback-box">
      <strong>Is it really fixed? Check the proof photo and confirm.</strong>
      <textarea
        className="text-area"
        rows={2}
        placeholder="Optional comment"
        value={comment}
        onChange={(e) => setComment(e.target.value)}
      />
      <div className="feedback-actions">
        <button type="button" className="approve-btn" disabled={busy} onClick={() => send(true)}>
          <ThumbsUp size={16} /> Yes, it's fixed
        </button>
        <button type="button" className="reject-btn" disabled={busy} onClick={() => send(false)}>
          <ThumbsDown size={16} /> Not fixed - reopen
        </button>
      </div>
      {error && <div className="error">{error}</div>}
    </div>
  );
}

function CitizenTicket({ ticket, onChanged }) {
  const [error, setError] = useState('');

  async function cancel() {
    if (!window.confirm('Cancel this ticket? Use this only if it was reported by mistake.')) return;
    setError('');
    try {
      await api.cancelReport(ticket.id);
      onChanged();
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <article className="ticket-card">
      <div className="ticket-top">
        <div>
          <strong>{ticketCode(ticket.id)}</strong>
          <span>{categoryLabel[ticket.category] || ticket.category}</span>
        </div>
        <span className={`badge badge-${ticket.status}`}>{citizenStatusLabel[ticket.status] || ticket.status}</span>
      </div>
      <p>{ticket.description || 'No description provided.'}</p>
      <div className="photo-pair">
        {ticket.photo_url && (
          <a href={resolveMediaUrl(ticket.photo_url)} target="_blank" rel="noreferrer">
            <img src={resolveMediaUrl(ticket.photo_url)} alt="Your photo" />
            <span>Your photo</span>
          </a>
        )}
        {ticket.latest_resolution_photo_url && (
          <a href={resolveMediaUrl(ticket.latest_resolution_photo_url)} target="_blank" rel="noreferrer">
            <img src={resolveMediaUrl(ticket.latest_resolution_photo_url)} alt="Proof of fix" />
            <span>Proof of fix</span>
          </a>
        )}
      </div>
      <div className="ticket-meta">
        <span><MapPin size={14} /> {ticket.latitude.toFixed(4)}, {ticket.longitude.toFixed(4)}</span>
        <span><Clock size={14} /> Reported {formatDate(ticket.created_at)}</span>
        <span>Dept: {ticket.assigned_department_name || 'Being routed'}</span>
        {ticket.assigned_officer_name && <span>Worker: {ticket.assigned_officer_name}</span>}
        {ticket.estimated_completion_at && <span>Expected by: {formatDate(ticket.estimated_completion_at)}</span>}
      </div>

      {ticket.status === 'resolved' && !ticket.citizen_verified && <Feedback ticket={ticket} onChanged={onChanged} />}
      {ticket.status === 'resolved' && ticket.citizen_verified && (
        <div className="resolved-box verified">
          <Verified size={18} /> You confirmed this was fixed. Thank you!
        </div>
      )}
      {ticket.status === 'pending_approval' && (
        <div className="resolved-box awaiting">
          <CheckCircle2 size={18} /> The worker uploaded proof - an officer is reviewing it.
        </div>
      )}
      {ticket.status === 'reopened' && (
        <div className="resolved-box reopened">
          <XCircle size={18} /> You reopened this ticket - the worker has to fix it again.
        </div>
      )}
      {CANCELLABLE.has(ticket.status) && (
        <button type="button" className="ghost small cancel-ticket" onClick={cancel}>
          <XCircle size={14} /> Cancel ticket
        </button>
      )}
      {error && <div className="error">{error}</div>}
    </article>
  );
}

export default function MyTickets({ tickets, loading, onChanged, onReport }) {
  if (loading && tickets.length === 0) {
    return <p className="empty-state">Loading your tickets...</p>;
  }
  if (tickets.length === 0) {
    return (
      <div className="empty-state">
        <p>You haven't reported anything yet.</p>
        <button type="button" className="primary" onClick={onReport}>Report an issue</button>
      </div>
    );
  }
  return (
    <section className="ticket-list">
      {tickets.map((ticket) => (
        <CitizenTicket key={ticket.id} ticket={ticket} onChanged={onChanged} />
      ))}
    </section>
  );
}
