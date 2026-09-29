import React, { useEffect, useMemo, useState } from 'react';
import { Save } from 'lucide-react';
import { api } from '../api/client';
import { formatDate, parseServerDate } from '../lib/format';

const STATUS_OPTIONS = [
  { id: 'segregated', label: 'Segregated', tone: 'good' },
  { id: 'partial', label: 'Partly segregated', tone: 'partial' },
  { id: 'mixed', label: 'Mixed waste', tone: 'bad' },
  { id: 'no_waste', label: 'No waste today', tone: 'neutral' },
  { id: 'not_available', label: 'House locked', tone: 'neutral' },
];

const WARD_KEY = 'jansetu_worker_last_ward';

function readWard() {
  try {
    return localStorage.getItem(WARD_KEY) || '';
  } catch {
    return '';
  }
}

/** Door-to-door collection round: record household segregation status. */
export default function CollectionRound({ officer }) {
  const [ward, setWard] = useState(readWard);
  const [household, setHousehold] = useState('');
  const [status, setStatus] = useState('');
  const [note, setNote] = useState('');
  const [logs, setLogs] = useState([]);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState(null);

  useEffect(() => {
    api.collections(officer.id).then(setLogs).catch((err) => setMessage({ error: true, text: err.message }));
  }, [officer.id]);

  const today = useMemo(() => {
    const now = new Date();
    return logs.filter((log) => parseServerDate(log.created_at)?.toDateString() === now.toDateString());
  }, [logs]);
  const segregated = today.filter((log) => log.status === 'segregated').length;
  const handedOver = today.filter((log) => ['segregated', 'partial', 'mixed'].includes(log.status)).length;

  async function save(event) {
    event.preventDefault();
    if (!ward.trim() || !household.trim() || !status) {
      setMessage({ error: true, text: 'Enter the ward, the household ID and pick a status.' });
      return;
    }
    setBusy(true);
    setMessage(null);
    try {
      const log = await api.logCollection({
        household_code: household.trim(),
        ward: ward.trim(),
        status,
        note: note.trim() || null,
        officer_id: officer.id,
      });
      try {
        localStorage.setItem(WARD_KEY, ward.trim());
      } catch {}
      setLogs([log, ...logs]);
      setHousehold('');
      setNote('');
      setStatus('');
      setMessage({ text: `Saved ${log.household_code}: ${STATUS_OPTIONS.find((o) => o.id === log.status)?.label}.` });
    } catch (err) {
      setMessage({ error: true, text: err.message });
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="swachh-grid">
      <form className="portal-panel collection-form" onSubmit={save}>
        <h3 className="panel-title">Log a household visit</h3>
        <div className="today-stats">
          <div><b>{today.length}</b><span>Visits today</span></div>
          <div><b>{segregated}</b><span>Segregated</span></div>
          <div><b>{handedOver ? `${Math.round((100 * segregated) / handedOver)}%` : '-'}</b><span>Compliance</span></div>
        </div>
        <label>
          Ward / area
          <input value={ward} onChange={(e) => setWard(e.target.value)} placeholder="e.g. Ward 1 - Yelahanka" />
        </label>
        <label>
          Household ID / door number
          <input value={household} onChange={(e) => setHousehold(e.target.value)} placeholder="e.g. H-045" />
        </label>
        <fieldset className="status-chips">
          <legend>Waste handed over</legend>
          {STATUS_OPTIONS.map((option) => (
            <button
              key={option.id}
              type="button"
              className={`status-chip ${option.tone} ${status === option.id ? 'active' : ''}`}
              aria-pressed={status === option.id}
              onClick={() => setStatus(option.id)}
            >
              {option.label}
            </button>
          ))}
        </fieldset>
        <label>
          Note (optional)
          <input value={note} onChange={(e) => setNote(e.target.value)} placeholder="e.g. explained segregation" />
        </label>
        {message && <div className={message.error ? 'error' : 'server-ok'}>{message.text}</div>}
        <button type="submit" className="primary" disabled={busy}>
          <Save size={16} /> {busy ? 'Saving...' : 'Save visit'}
        </button>
      </form>

      <section className="portal-panel">
        <h3 className="panel-title">Recent visits</h3>
        {logs.length === 0 ? (
          <p className="panel-empty">No visits logged yet.</p>
        ) : (
          <ul className="offender-list">
            {logs.slice(0, 25).map((log) => {
              const option = STATUS_OPTIONS.find((o) => o.id === log.status);
              return (
                <li key={log.id}>
                  <span className="mono">{log.household_code}</span>
                  <span>{log.ward} · {formatDate(log.created_at)}</span>
                  <b className={`chip-text ${option?.tone}`}>{option?.label || log.status}</b>
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </div>
  );
}
