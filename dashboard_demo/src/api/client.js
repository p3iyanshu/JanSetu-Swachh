const API_BASE_URL = 'http://localhost:8000/api/v1';
const API_ROOT_URL = API_BASE_URL.replace(/\/api\/v1$/, '');

export function resolveMediaUrl(pathOrUrl) {
  if (!pathOrUrl) return pathOrUrl;
  if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) return pathOrUrl;
  return `${API_ROOT_URL}${pathOrUrl}`;
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
  const res = await fetch(`${API_BASE_URL}${path}`, options);
  if (!res.ok) {
    const payload = await res.json().catch(() => ({}));
    throw new Error(extractErrorMessage(payload, `Request failed: ${res.status}`));
  }
  return res.json();
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
