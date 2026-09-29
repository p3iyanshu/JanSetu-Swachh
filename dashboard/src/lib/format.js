export const statusLabel = {
  submitted: 'Submitted',
  assigned: 'Assigned to Dept',
  in_progress: 'In Progress',
  pending_approval: 'Pending Admin Approval',
  resolved: 'Resolved',
  reopened: 'Reopened',
  cancelled: 'Cancelled by Citizen',
};

// Friendlier wording for the citizen's own view of their tickets.
export const citizenStatusLabel = {
  submitted: 'Submitted',
  assigned: 'Assigned',
  in_progress: 'Work in progress',
  pending_approval: 'Under review',
  resolved: 'Resolved',
  reopened: 'Reopened',
  cancelled: 'Cancelled',
};

export const OPEN_STATUSES = new Set(['submitted', 'assigned', 'in_progress', 'reopened']);

// Backend timestamps are naive UTC - without the "Z" the browser would
// read them as local time and every date would be off by the UTC offset.
export function parseServerDate(value) {
  if (!value) return null;
  return new Date(/[zZ]|[+-]\d\d:\d\d$/.test(value) ? value : `${value}Z`);
}

export function formatDate(value) {
  const date = parseServerDate(value);
  if (!date) return 'Not set';
  return date.toLocaleString();
}

export function isOverdue(ticket) {
  const deadline = parseServerDate(ticket.sla_deadline);
  return Boolean(deadline) && OPEN_STATUSES.has(ticket.status) && deadline < new Date();
}

export function ticketCode(id) {
  return `JAN-${String(id).padStart(6, '0')}`;
}
