import React, { useState } from 'react';
import { Camera, Clock, MapPin, Navigation, Play, Upload, XCircle } from 'lucide-react';
import { api, resolveMediaUrl } from '../api/client';
import { SWACHH_CATEGORIES, categoryLabel } from '../lib/categories';
import { formatDate, isOverdue, statusLabel, ticketCode } from '../lib/format';

function currentPosition() {
  return new Promise((resolve) => {
    if (!navigator.geolocation) return resolve(null);
    navigator.geolocation.getCurrentPosition(
      (position) => resolve({ lat: position.coords.latitude, lng: position.coords.longitude }),
      () => resolve(null),
      { enableHighAccuracy: true, timeout: 10000 },
    );
  });
}

export default function WorkerTicket({ ticket, officer, onChanged }) {
  const [file, setFile] = useState(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState(null);
  const mine = ticket.assigned_officer_id === officer.id;

  async function run(action) {
    setBusy(true);
    setMessage(null);
    try {
      await action();
      onChanged();
    } catch (err) {
      setMessage({ error: true, text: err.message });
    } finally {
      setBusy(false);
    }
  }

  function startWork() {
    run(() => api.startWork(ticket.id, officer.id));
  }

  function submitProof() {
    if (!file) return;
    run(async () => {
      // The proof must be geo-tagged. Browsers only share GPS over HTTPS or
      // localhost - if it isn't available, fall back to the ticket's location
      // and say so, rather than blocking the worker.
      const position = await currentPosition();
      const form = new FormData();
      form.append('officer_id', officer.id);
      form.append('latitude', position?.lat ?? ticket.latitude);
      form.append('longitude', position?.lng ?? ticket.longitude);
      form.append('captured_at', new Date().toISOString().slice(0, 19));
      form.append('after_photo', file);
      await api.resolve(ticket.id, form);
      setFile(null);
      if (!position) {
        setMessage({ text: 'Proof submitted. Browser GPS was unavailable, so the ticket location was used.' });
      }
    });
  }

  const mapsUrl = `https://www.google.com/maps/search/?api=1&query=${ticket.latitude},${ticket.longitude}`;

  return (
    <article className="ticket-card">
      <div className="ticket-top">
        <div>
          <strong>{ticketCode(ticket.id)}</strong>
          <span>
            {categoryLabel[ticket.category] || ticket.category}
            {SWACHH_CATEGORIES.has(ticket.category) && <em className="swachh-tag">Swachh</em>}
          </span>
        </div>
        <div className="ticket-badges">
          {isOverdue(ticket) && <span className="badge badge-overdue">SLA overdue</span>}
          <span className={`badge badge-${ticket.status}`}>{statusLabel[ticket.status] || ticket.status}</span>
        </div>
      </div>
      <p>{ticket.description || 'No description provided.'}</p>
      <div className="photo-pair">
        {ticket.photo_url && (
          <a href={resolveMediaUrl(ticket.photo_url)} target="_blank" rel="noreferrer">
            <img src={resolveMediaUrl(ticket.photo_url)} alt="Reported issue" />
            <span>Citizen photo</span>
          </a>
        )}
        {ticket.latest_resolution_photo_url && (
          <a href={resolveMediaUrl(ticket.latest_resolution_photo_url)} target="_blank" rel="noreferrer">
            <img src={resolveMediaUrl(ticket.latest_resolution_photo_url)} alt="Your proof" />
            <span>Your proof</span>
          </a>
        )}
      </div>
      <div className="ticket-meta">
        <span><MapPin size={14} /> {ticket.latitude.toFixed(4)}, {ticket.longitude.toFixed(4)}</span>
        <span><Clock size={14} /> Reported {formatDate(ticket.created_at)}</span>
        <span>Due: {formatDate(ticket.estimated_completion_at || ticket.sla_deadline)}</span>
        <span>Worker: {ticket.assigned_officer_name || 'Not assigned'}</span>
        <a className="maps-link" href={mapsUrl} target="_blank" rel="noreferrer">
          <Navigation size={14} /> Navigate
        </a>
      </div>

      {ticket.admin_review_comment && ticket.status === 'in_progress' && (
        <div className="resolved-box rejected">
          <XCircle size={18} /> Sent back by admin: "{ticket.admin_review_comment}"
        </div>
      )}

      {mine && ticket.status === 'assigned' && (
        <div className="resolve-row">
          <span>Assigned to you - start when you reach the spot.</span>
          <span />
          <button type="button" onClick={startWork} disabled={busy}>
            <Play size={16} /> Start work
          </button>
        </div>
      )}

      {mine && (ticket.status === 'in_progress' || ticket.status === 'reopened') && (
        <div className="resolve-row">
          <label className="camera-button">
            <Camera size={18} />
            {file ? 'Change photo' : 'Capture "after" photo'}
            <input type="file" accept="image/*" capture="environment" onChange={(e) => setFile(e.target.files?.[0] || null)} />
          </label>
          <span>{file ? file.name : 'Photo of the cleaned spot is required'}</span>
          <button type="button" onClick={submitProof} disabled={!file || busy}>
            <Upload size={16} /> {busy ? 'Uploading...' : 'Submit proof'}
          </button>
        </div>
      )}

      {mine && ticket.status === 'pending_approval' && (
        <div className="resolved-box awaiting">Proof submitted - waiting for admin approval.</div>
      )}

      {message && <div className={message.error ? 'error' : 'server-ok'}>{message.text}</div>}
    </article>
  );
}
