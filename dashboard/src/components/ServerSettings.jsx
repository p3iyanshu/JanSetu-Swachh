import React, { useState } from 'react';
import { Server } from 'lucide-react';
import { clearStoredServer, getApiBaseUrl, hasStoredServer, testAndSaveServer } from '../api/client';

function displayServer() {
  return getApiBaseUrl().replace(/^https?:\/\//, '').replace(/\/api\/v1$/, '');
}

/** Compact "Server: host:port" link that expands into an address editor. */
export default function ServerSettings() {
  const [open, setOpen] = useState(false);
  const [value, setValue] = useState(displayServer);
  const [status, setStatus] = useState(null);
  const [busy, setBusy] = useState(false);

  async function save() {
    setBusy(true);
    setStatus(null);
    try {
      const saved = await testAndSaveServer(value);
      setStatus({ ok: true, text: `Connected to ${saved.replace(/\/api\/v1$/, '')}` });
    } catch (err) {
      setStatus({ ok: false, text: err.message });
    } finally {
      setBusy(false);
    }
  }

  if (!open) {
    return (
      <button type="button" className="server-toggle" onClick={() => setOpen(true)}>
        <Server size={14} /> Server: {displayServer()}
      </button>
    );
  }

  return (
    <div className="server-settings">
      <label>
        Backend server address
        <input value={value} onChange={(e) => setValue(e.target.value)} placeholder="192.168.1.5:8000" />
      </label>
      <div className="server-actions">
        <button type="button" className="ghost small" onClick={() => setOpen(false)}>Close</button>
        {hasStoredServer() && (
          <button
            type="button"
            className="ghost small"
            onClick={() => {
              clearStoredServer();
              setValue(displayServer());
              setStatus({ ok: true, text: `Using the default server: ${displayServer()}` });
            }}
          >
            Use default
          </button>
        )}
        <button type="button" className="ghost small" onClick={save} disabled={busy}>
          {busy ? 'Testing...' : 'Test & Save'}
        </button>
      </div>
      {status && <div className={status.ok ? 'server-ok' : 'error'}>{status.text}</div>}
    </div>
  );
}
