import React, { useEffect, useState } from 'react';
import { HardHat, Info, Leaf, LogIn, MapPinned, Recycle, ShieldCheck, UserRound } from 'lucide-react';
import { api } from '../api/client';
import ServerSettings from '../components/ServerSettings';
import { DEMO_ACCOUNTS } from './demoAccounts';

const ROLES = [
  { id: 'citizen', title: 'Citizen', subtitle: 'Report & track issues', icon: UserRound },
  { id: 'worker', title: 'Worker', subtitle: 'Resolve tickets, log rounds', icon: HardHat },
  { id: 'admin', title: 'Admin', subtitle: 'Assign, approve, analyse', icon: ShieldCheck },
];

const HIGHLIGHTS = [
  { icon: MapPinned, text: 'Report garbage, dumping, missed pickups and toilets with a photo and GPS' },
  { icon: Recycle, text: 'Door-to-door segregation tracking for every household' },
  { icon: Leaf, text: 'Hotspot maps and verified, photo-proof cleanups' },
];

function initialForm(role) {
  if (role === 'citizen') return { phone: DEMO_ACCOUNTS.citizen.phone, otp: DEMO_ACCOUNTS.citizen.otp };
  const demo = DEMO_ACCOUNTS[role];
  return { empId: demo.empId, password: demo.password, name: '', departmentId: '' };
}

export default function PortalLogin({ onLogin, initialRole = 'citizen' }) {
  const [role, setRole] = useState(initialRole);
  const [mode, setMode] = useState('login');
  const [form, setForm] = useState(() => initialForm(initialRole));
  const [departments, setDepartments] = useState([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (mode === 'register' && role === 'worker' && departments.length === 0) {
      api.departments().then(setDepartments).catch(() => {});
    }
  }, [mode, role, departments.length]);

  function selectRole(nextRole) {
    setRole(nextRole);
    setMode('login');
    setForm(initialForm(nextRole));
    setError('');
  }

  function update(field) {
    return (event) => setForm({ ...form, [field]: event.target.value });
  }

  async function loginCitizen() {
    const phone = form.phone.trim();
    if (phone.replace(/\D/g, '').length < 10) throw new Error('Enter a valid 10-digit phone number.');
    await api.requestOtp(phone);
    const user = await api.verifyOtp(phone, form.otp.trim());
    return { role: 'citizen', user };
  }

  async function loginEmployee() {
    const officer =
      mode === 'register'
        ? await api.signup({
            name: form.name.trim(),
            emp_id: form.empId.trim(),
            password: form.password,
            department_id: role === 'worker' ? Number(form.departmentId) : null,
          })
        : await api.login({ emp_id: form.empId.trim(), password: form.password });

    if (role === 'worker' && officer.department_id == null) {
      throw new Error('This is a platform admin account. Choose "Admin" to sign in.');
    }
    if (role === 'admin' && officer.department_id != null && !officer.is_department_head) {
      throw new Error('This is a field worker account. Choose "Worker" to sign in.');
    }
    return { role, user: officer };
  }

  async function submit(event) {
    event.preventDefault();
    setBusy(true);
    setError('');
    try {
      onLogin(role === 'citizen' ? await loginCitizen() : await loginEmployee());
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  const demo = DEMO_ACCOUNTS[role];
  const isRegister = mode === 'register';

  return (
    <main className="portal-login">
      <section className="portal-brand">
        <div className="portal-brand-inner">
          <img src="/indian-emblem.png" alt="Emblem of India" className="portal-emblem" />
          <h1>JanSetu-Swachh</h1>
          <p className="portal-tagline">Crowdsourced civic &amp; sanitation issue reporting and resolution</p>
          <ul className="portal-highlights">
            {HIGHLIGHTS.map(({ icon: Icon, text }) => (
              <li key={text}>
                <Icon size={18} /> {text}
              </li>
            ))}
          </ul>
          <p className="portal-footnote">Smart India Hackathon 2026 · SIH26195 · Clean &amp; Green Technology</p>
        </div>
      </section>

      <section className="portal-form-side">
        <form className="portal-card" onSubmit={submit}>
          <h2>Sign in</h2>
          <p className="portal-sub">Choose how you want to use JanSetu-Swachh</p>

          <div className="role-picker" role="radiogroup" aria-label="Login type">
            {ROLES.map(({ id, title, subtitle, icon: Icon }) => (
              <button
                key={id}
                type="button"
                role="radio"
                aria-checked={role === id}
                className={`role-option ${role === id ? 'active' : ''}`}
                onClick={() => selectRole(id)}
              >
                <Icon size={22} />
                <strong>{title}</strong>
                <span>{subtitle}</span>
              </button>
            ))}
          </div>

          {!isRegister && (
            <div className="demo-note">
              <Info size={16} />
              <span>
                Demo credentials are filled in - just click <b>Login</b>.
                {role === 'citizen'
                  ? ` Phone ${demo.phone} · OTP ${demo.otp}`
                  : ` ID ${demo.empId} · Password ${demo.password}`}
              </span>
            </div>
          )}

          {role === 'citizen' ? (
            <>
              <label>
                Phone number
                <div className="input-prefix">
                  <span>+91</span>
                  <input value={form.phone} onChange={update('phone')} inputMode="tel" autoComplete="tel" required />
                </div>
              </label>
              <label>
                OTP
                <input value={form.otp} onChange={update('otp')} inputMode="numeric" autoComplete="one-time-code" required />
              </label>
            </>
          ) : (
            <>
              {isRegister && (
                <label>
                  Full name
                  <input value={form.name} onChange={update('name')} required />
                </label>
              )}
              <label>
                {role === 'worker' ? 'Employee ID' : 'Admin ID'}
                <input value={form.empId} onChange={update('empId')} autoComplete="username" required />
              </label>
              {isRegister && role === 'worker' && (
                <label>
                  Department
                  <select value={form.departmentId} onChange={update('departmentId')} required>
                    <option value="">Select your department</option>
                    {departments.map((department) => (
                      <option key={department.id} value={department.id}>
                        {department.name}
                      </option>
                    ))}
                  </select>
                </label>
              )}
              <label>
                Password
                <input
                  type={isRegister ? 'password' : 'text'}
                  value={form.password}
                  onChange={update('password')}
                  autoComplete={isRegister ? 'new-password' : 'current-password'}
                  required
                />
              </label>
            </>
          )}

          {error && <div className="error">{error}</div>}

          <button className="primary portal-submit" type="submit" disabled={busy}>
            <LogIn size={18} />
            {busy ? 'Please wait...' : isRegister ? 'Register & Login' : `Login as ${ROLES.find((r) => r.id === role).title}`}
          </button>

          {role !== 'citizen' && (
            <button
              type="button"
              className="link-button portal-switch"
              onClick={() => {
                setMode(isRegister ? 'login' : 'register');
                setForm(isRegister ? initialForm(role) : { empId: '', password: '', name: '', departmentId: '' });
                setError('');
              }}
            >
              {isRegister ? 'Back to login' : `New ${role === 'worker' ? 'employee' : 'admin'}? Register`}
            </button>
          )}

          <ServerSettings />
        </form>
      </section>
    </main>
  );
}
