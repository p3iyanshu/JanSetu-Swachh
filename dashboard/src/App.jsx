import React, { useEffect, useState } from 'react';
import AdminApp from './admin/AdminApp';
import CitizenApp from './citizen/CitizenApp';
import PortalLogin from './portal/PortalLogin';
import WorkerApp from './worker/WorkerApp';

// One web portal for all three roles. The signed-in role + user is kept in
// localStorage so a refresh doesn't log you out.
const SESSION_KEY = 'jansetu_portal_session';
const ROLES = new Set(['citizen', 'worker', 'admin']);

function readSession() {
  try {
    const session = JSON.parse(localStorage.getItem(SESSION_KEY));
    return session && ROLES.has(session.role) && session.user ? session : null;
  } catch {
    return null;
  }
}

// ?role=admin (or worker/citizen) preselects the login type - handy for
// links in docs or the admin desktop app.
function roleFromUrl() {
  const role = new URLSearchParams(window.location.search).get('role');
  return ROLES.has(role) ? role : 'citizen';
}

export default function App() {
  const [session, setSession] = useState(readSession);

  useEffect(() => {
    const titles = { citizen: 'Citizen', worker: 'Worker', admin: 'Admin' };
    document.title = session ? `JanSetu-Swachh · ${titles[session.role]}` : 'JanSetu-Swachh';
  }, [session]);

  function login(next) {
    try {
      localStorage.setItem(SESSION_KEY, JSON.stringify(next));
    } catch {}
    setSession(next);
  }

  function logout() {
    try {
      localStorage.removeItem(SESSION_KEY);
    } catch {}
    setSession(null);
  }

  if (!session) return <PortalLogin onLogin={login} initialRole={roleFromUrl()} />;
  if (session.role === 'citizen') return <CitizenApp user={session.user} onLogout={logout} />;
  if (session.role === 'worker') return <WorkerApp user={session.user} onLogout={logout} />;
  return <AdminApp me={session.user} onLogout={logout} />;
}
