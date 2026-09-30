// Backend address, in order of preference:
//   1. the "Server address" saved on the login screen (this browser only)
//   2. server.json published with the website - lets the backend address
//      change (e.g. a new tunnel) without rebuilding the site, APK or exe
//   3. VITE_API_BASE_URL at build time, then localhost.
const SERVER_KEY = 'jansetu_api_base_url';
const BUILD_DEFAULT_API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000/api/v1';
const CONFIG_URL = import.meta.env.VITE_CONFIG_URL || '/server.json';
let remoteApiBaseUrl = null;

/** Reads server.json once at startup. Never throws; gives up after 4 s. */
export async function loadRemoteConfig() {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 4000);
  try {
    const res = await fetch(CONFIG_URL, { cache: 'no-store', signal: controller.signal });
    if (!res.ok) return;
    const config = await res.json();
    if (typeof config.api_base_url === 'string' && /^https?:\/\//.test(config.api_base_url)) {
      remoteApiBaseUrl = config.api_base_url.replace(/\/+$/, '');
    }
  } catch {
    // Offline or no config published - fall back to the build-time default.
  } finally {
    clearTimeout(timer);
  }
}

function readStoredServer() {
  try {
    return localStorage.getItem(SERVER_KEY);
  } catch {
    return null;
  }
}

export function clearStoredServer() {
  try {
    localStorage.removeItem(SERVER_KEY);
  } catch {}
}

export function hasStoredServer() {
  return Boolean(readStoredServer());
}

export function getApiBaseUrl() {
  return readStoredServer() || remoteApiBaseUrl || BUILD_DEFAULT_API_BASE_URL;
}

function getApiRootUrl() {
  return getApiBaseUrl().replace(/\/api\/v1$/, '');
}

// Accepts "192.168.1.5", "192.168.1.5:8000", "http://host:8000" or a full
// ".../api/v1" URL. Returns null when it can't be an address.
export function normalizeServerAddress(input) {
  let value = (input || '').trim();
  if (!value) return null;
  if (!/^https?:\/\//.test(value)) value = `http://${value}`;
  try {
    const url = new URL(value);
    if (!url.hostname) return null;
    const port = url.port || (url.protocol === 'https:' ? '' : '8000');
    const path = url.pathname.replace(/\/+$/, '');
    return `${url.protocol}//${url.hostname}${port ? `:${port}` : ''}${path.endsWith('/api/v1') ? path : `${path}/api/v1`}`;
  } catch {
    return null;
  }
}

export async function testAndSaveServer(input) {
  const baseUrl = normalizeServerAddress(input);
  if (!baseUrl) throw new Error('Enter an address like 192.168.1.5 or 192.168.1.5:8000');
  const root = baseUrl.replace(/\/api\/v1$/, '');
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 5000);
  try {
    const res = await fetch(`${root}/health`, { signal: controller.signal });
    if (!res.ok) throw new Error();
  } catch {
    throw new Error(`Could not reach the backend at ${root}. Check the address and that it's running.`);
  } finally {
    clearTimeout(timer);
  }
  try {
    localStorage.setItem(SERVER_KEY, baseUrl);
  } catch {}
  return baseUrl;
}

export function resolveMediaUrl(pathOrUrl) {
  if (!pathOrUrl) return pathOrUrl;
  if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) return pathOrUrl;
  return `${getApiRootUrl()}${pathOrUrl}`;
}

function extractErrorMessage(payload, fallback) {
  const { detail } = payload;
  if (typeof detail === 'string') return detail;
  if (Array.isArray(detail)) {
    return detail
      .map((item) => (typeof item === 'string' ? item : item.msg || JSON.stringify(item)))
      .join('; ');
  }
  return fallback;
}

async function request(path, options = {}) {
  let res;
  try {
    res = await fetch(`${getApiBaseUrl()}${path}`, options);
  } catch {
    throw new Error(`Can't reach the JanSetu server at ${getApiRootUrl()}. Check it's running, or change the server address.`);
  }
  if (!res.ok) {
    const payload = await res.json().catch(() => ({}));
    throw new Error(extractErrorMessage(payload, `Request failed: ${res.status}`));
  }
  return res.json();
}

function postJson(path, body) {
  return request(path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

export const api = {
  reports: () => request('/reports/'),
  stats: () => request('/reports/stats'),
  departments: () => request('/departments/'),
  officers: (departmentId) =>
    request(`/admin/officers${departmentId ? `?department_id=${departmentId}` : ''}`),
  signup: (payload) =>
    request('/admin/signup', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    }),
  login: (payload) =>
    request('/admin/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    }),
  assign: (reportId, payload) =>
    request(`/admin/reports/${reportId}/assign`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    }),
  startWork: (reportId, officerId) =>
    request(`/admin/reports/${reportId}/start`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ officer_id: officerId }),
    }),
  eligibleWorkers: (reportId) => request(`/admin/reports/${reportId}/eligible-workers`),
  approve: (reportId, comment) =>
    request(`/admin/reports/${reportId}/approve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ comment: comment || null }),
    }),
  reject: (reportId, comment) =>
    request(`/admin/reports/${reportId}/reject`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ comment: comment || null }),
    }),
  resolve: (reportId, formData) =>
    request(`/admin/reports/${reportId}/resolve`, {
      method: 'POST',
      body: formData,
    }),
  availability: (officerId, isAvailable) =>
    request(`/admin/officers/${officerId}/availability`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ is_available: isAvailable }),
    }),
  removeOfficer: (officerId) =>
    request(`/admin/officers/${officerId}`, {
      method: 'DELETE',
    }),
  // Citizen
  requestOtp: (phone) => postJson('/auth/request-otp', { phone }),
  verifyOtp: (phone, otp) => postJson('/auth/verify-otp', { phone, otp }),
  uploadPhoto: (file) => {
    const form = new FormData();
    form.append('file', file);
    return request('/reports/upload-photo', { method: 'POST', body: form });
  },
  analyzeIssue: (file) => {
    const form = new FormData();
    form.append('file', file);
    return request('/ai/analyze-issue', { method: 'POST', body: form });
  },
  createReport: (payload) => postJson('/reports/', payload),
  myReports: (userId) => request(`/reports/?user_id=${userId}`),
  feedback: (reportId, satisfied, comment) =>
    postJson(`/reports/${reportId}/feedback`, { satisfied, comment: comment || null }),
  cancelReport: (reportId, reason) => postJson(`/reports/${reportId}/cancel`, { reason: reason || null }),
  citizenImpact: (userId) => request(`/swachh/citizens/${userId}/impact`),
  wasteGuide: () => request('/swachh/waste-guide'),
  // Worker
  assignedTo: (officerId) => request(`/admin/reports/assigned-to/${officerId}`),
  departmentReports: (departmentId) => request(`/admin/reports/department/${departmentId}`),
  collections: (officerId) => request(`/swachh/collections?officer_id=${officerId}&limit=100`),
  logCollection: (payload) => postJson('/swachh/collections', payload),
  // Admin
  swachhSummary: (days) => request(`/swachh/summary?days=${days}`),
  swachhHotspots: (days) => request(`/swachh/hotspots?days=${days}`),
  segregationStats: (days) => request(`/swachh/segregation-stats?days=${days}`),
};

export async function fetchReports() {
  try {
    return await api.reports();
  } catch (err) {
    console.warn('Backend connection issue:', err);
    return [];
  }
}

export async function fetchReportStats() {
  try {
    return await api.stats();
  } catch (err) {
    console.warn('Backend connection issue:', err);
    return { open_count: 0, in_progress_count: 0, resolved_count: 0, avg_resolution_hours: 0 };
  }
}

export async function fetchLeaderboard() {
  try {
    return await request('/departments/leaderboard');
  } catch (err) {
    console.warn('Backend connection issue:', err);
    return [];
  }
}
