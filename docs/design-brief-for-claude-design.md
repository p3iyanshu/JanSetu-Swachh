# JanSetu Admin Dashboard — Visual Redesign Brief

**Prepared for:** Claude Design
**Prepared from:** a read-only audit of `D:\JanSetu\dashboard` (React + Vite admin dashboard, current commit as of this brief)
**Purpose:** Produce a high-fidelity visual concept for a pure aesthetic redesign of the JanSetu admin dashboard.

---

## 1. PROJECT CONTEXT

JanSetu is a civic issue reporting and resolution platform built for Smart India Hackathon 2026. Citizens report civic problems (potholes, garbage overflow, water leakage, sewage overflow, etc.) through a mobile app; this dashboard is the **government/department-facing side** — used by municipal department officers and platform administrators to triage, assign, review, and close out those tickets. It is not seen by citizens. It needs to feel authoritative, trustworthy, and dignified — the way a well-designed government platform should — not like a consumer app or a venture-funded startup's admin panel.

---

## 2. HARD CONSTRAINT — READ THIS FIRST

This is a **pure visual/aesthetic redesign**. No functionality, data structure, component logic, routing, or interaction may change. Every screen, component, and piece of displayed data listed in the inventory below (Section 6) must remain **exactly as-is** in terms of what it shows and how it behaves — **only how it looks should change.** Treat the inventory as the literal, complete scope of content to restyle. If it isn't in the inventory, it doesn't exist in the product — do not add it.

---

## 3. DESIGN DIRECTION

**Quality bar:** This should look like it was designed by a senior graphic designer for a serious, professional civic platform — not a template, not a generic admin dashboard UI kit, not an AI-generated "safe default" look. If it could be mistaken for a Tailwind admin-template screenshot, it has missed the brief.

**National identity — subtle, not literal:** Incorporate a tasteful, restrained nod to Indian national identity: a refined use of the tricolor's palette family (saffron, white, India green, and a navy standing in for the Ashoka Chakra's blue) as accent tones within an otherwise sophisticated, muted base palette — **not** a flag graphic on the header. Reference the visual dignity of well-designed official Indian government digital platforms (in the spirit of Digital India's visual language): confident, clean, a little warm, never gaudy or overly literal. Concretely:
- A fine tricolor hairline (saffron → warm off-white → deep green) used once, structurally — e.g. as a top edge accent on the page shell or header — not repeated as decoration throughout the UI.
- An Ashoka Chakra–inspired mark (a simple 24-spoke wheel rendered as thin line art) used sparingly — e.g. as a small accent beside the wordmark or as a loading/status motif — never as a dominant graphic, never literally colored like the flag.
- This should read as "quietly patriotic and dignified," not "loud and literal." If someone would describe it as looking like a flag was pasted on, it has gone too far.

**Typography — proposed pairing (not a placeholder; use these unless you have a stronger, equally well-reasoned alternative):**
- **Headings & large numbers** (page titles, the four metric-tile figures, section headers): **Fraunces** — a warm, high-contrast serif with real character. It gives the dashboard gravitas and a considered, editorial-quality feel appropriate to a public institution, without reading as stuffy.
- **UI text, labels, body copy, table/card content**: **IBM Plex Sans** — chosen deliberately, not as a generic sans default: IBM Plex was designed as an institutional systems typeface (engineered for clarity across a large product family), which is exactly the register this dashboard needs — precise, legible at small sizes, unmistakably "designed with intention" rather than left at browser defaults.
- **Ticket IDs, coordinates, and other precise/tabular data** (e.g. `JAN-000042`, `13.0827°, 77.5877°`): **IBM Plex Mono** — a small, deliberate touch that makes identifiers and figures read as precise/official rather than incidental.
- Currently the app loads only "Inter" from Google Fonts and uses it as the sole typeface throughout (see Section 6.4). This pairing is a deliberate upgrade, not a swap of one sans for another.

**Layout:** Information-dense but not cluttered — department heads need to scan this quickly, often under time pressure. Maintain the current structural hierarchy (header → headline metrics → department capacity at a glance → ticket list with filters), but sharpen the visual hierarchy so:
- Urgent/attention-needing items (unassigned tickets, pending approvals, and especially anything SLA-breached — see Section 5) are unmistakably distinct from routine status information, using color + weight, not just a badge color swap.
- The current "Needs Attention" toggle/badge concept (Section 6.3) should read as a genuine alert affordance, not a muted secondary button.
- Status badges (submitted/assigned/in-progress/pending-approval/resolved/reopened — Section 6.3) remain colored, distinct, and scannable at a glance across a long list of ticket cards.

---

## 4. WHAT TO PRODUCE

1. **A full visual mockup of the main dashboard view** — the authenticated admin screen described in Section 6.3 (header, the four headline metric tiles, the per-department "free workers" tiles, the filters bar, and a representative set of ticket cards showing at least: an unassigned ticket with the assign-worker control, an in-progress ticket, a pending-approval ticket with the review panel, and a resolved ticket) — reflecting the direction above.
2. **The defined color system** (Section 5) and **typography choices** (Section 3), documented clearly enough that a developer could turn them into a CSS theme/variables file afterward without further interpretation.
3. Spacing/sizing guidance (Section 5.3) applied consistently across the mockup — not just a color reskin of the existing layout.

---

## 5. COLOR & SPACING SYSTEM

### 5.1 Base palette

| Token | Hex | Use | Rationale |
|---|---|---|---|
| `--bg` | `#F7F5F1` | Page background | A warm, soft off-white rather than the current cool blue-gray (`#eef3f8`) or stark white — reads as "paper/official document," not clinical or SaaS-cold. |
| `--surface` | `#FFFFFF` | Card/panel backgrounds | Clean white surfaces sit slightly lifted off the warm background — keeps content legible while the warmth lives in the negative space. |
| `--border` | `#E4DFD6` | Hairline borders on cards/inputs | A warm neutral gray-beige, replacing the current cool `#dbe3ee` — consistent with the warm base rather than a leftover "corporate blue" tint. |
| `--text-primary` | `#1C1B18` | Primary text | Near-black with a warm undertone, not a cold slate (`#0f172a`) — pairs with the warm background/border system. |
| `--text-secondary` | `#6B6559` | Secondary/meta text (dates, labels, counts) | Warm gray, legible but clearly subordinate. |

### 5.2 Primary, accent, and status colors

| Token | Hex | Use | Rationale |
|---|---|---|---|
| `--primary` | `#14213D` | Primary actions, active nav state, header wordmark | A deep, dignified navy — stands in for the Ashoka Chakra blue. Chosen over the current generic SaaS blue (`#0b63ce`) because navy reads as authoritative and institutional; it's the color family most associated with credible Indian e-governance services already. |
| `--accent-saffron` | `#C8791E` | Primary CTA buttons (e.g. "Assign", "Approve"), the tricolor hairline, sparing highlight use | A toned-down, dignified saffron — closer to turmeric/terracotta than the flag's literal bright `#FF9933`, so it reads as a considered accent, not a flag reference. |
| `--accent-green` | `#136F3C` | Secondary confirmation accents, the tricolor hairline | A deep, muted "India green" (flag green is `#138808`; toned for sophistication) — doubles as part of the resolved-status story below. |
| `--status-open` | `#2C4A78` | Submitted / newly-open tickets | A calmer, lighter navy than `--primary` — informational, not alarming: these are new but not yet late. |
| `--status-in-progress` | `#C8791E` | In-progress tickets (shares the saffron accent) | Warm and active — signals work is genuinely underway. |
| `--status-resolved` | `#136F3C` | Resolved / fully closed tickets | Deep green — unambiguous success, ties back to the national-palette accent. |
| `--status-sla-breached` | `#B3261E` | Tickets past their SLA deadline | A serious, deliberate alert red (not a bright candy red) — the one color in the system that should visually interrupt a quick scan. **Note:** the current app does not yet compute or display an "SLA-breached" state anywhere in the UI (see Section 6.6) — this token is defined now so the theme system is ready whenever that indicator is added; do not invent a new badge/section to show it in the mockup beyond what Section 6 lists as currently existing. |
| `--status-reopened` | `#7A3B69` | Reopened tickets | A muted plum, deliberately distinct from the SLA-breach red so the two "needs attention" states never get visually confused at a glance. |
| `--status-pending-approval` | `#5B4B8A` | Pending admin approval (worker submitted proof) | Kept in the violet family the current app already uses for this state (`#6d28d9`), muted to match the new palette. |
| `--status-assigned` | `#8A6A2F` | Assigned to department, worker not yet picked | A muted gold/ochre — distinct from both open (navy) and in-progress (saffron) while staying in the warm family. |

### 5.3 Spacing, radius, and elevation

- **Spacing scale:** 4px base unit — 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40.
- **Card padding:** 20–24px (current build uses 16px throughout — slightly tight for the "considered, unhurried" feel this brief wants).
- **Border radius:** 6px on small controls (inputs, badges, buttons), 12px on cards and panels (current build uses a flat 6–8px everywhere — a touch more radius on containers reads as more considered without tipping into a trendy "rounded-everything" look).
- **Shadow:** a soft, layered elevation instead of the current single flat shadow (`0 8px 24px rgba(15,23,42,0.06)`) — e.g. a tight contact shadow plus a soft ambient shadow, both warm-toned rather than cool slate, so cards feel gently lifted rather than glassy or heavy.
- **Borders:** hairline 1px throughout, using `--border` above.

---

## 6. CURRENT STATE INVENTORY (from the audit)

This section exists so the brief references real component names and real displayed data, not guesses. Everything in this section is in scope for the redesign; nothing outside it should be added.

### 6.1 Screens (2 total)

The dashboard is a single-page React app with no router — it's a client-side auth gate over one screen:

1. **Login / Signup screen** (`LoginScreen` component) — shown when no admin session is stored.
2. **Main Admin Dashboard** (default export of `App.jsx`) — one continuous authenticated view containing all sections below. There is no multi-page navigation to design for.

### 6.2 Login / Signup screen — content inventory

- Brand mark (currently a shield icon) + "JanSetu" wordmark + "Admin" subtitle.
- Sign In / Signup segmented toggle.
- Signup-only fields: Admin Name, Contact.
- Shared fields: Admin ID, Password.
- Inline error message banner (on failed login/signup).
- Submit button (label changes: "SIGN IN" / "REGISTER").
- *Existing detail worth preserving in spirit:* the login screen already has a subtle diagonal tricolor gradient wash (saffron → white → green) behind the panel — this is the one place in the current app that already gestures at the national palette, and is a reasonable seed for the new direction.

### 6.3 Main Dashboard — content inventory

**Header**
- "JanSetu Admin" title.
- Subtitle line: officer name · their department name (or "Platform Admin" if unassigned to a department) · "All Tickets".
- "Needs Attention" toggle button — shows a bell icon, a numeric badge (count of tickets needing action), and changes visual state when active/toggled or when the count is > 0.
- Logout button.

**Headline metrics (4 tiles, always visible)**
- Dept Queue (count of `assigned`-status tickets)
- In Progress (count)
- Pending Approval (count)
- Fully Closed (count of resolved + citizen-verified tickets)

**Department capacity tiles (one per department, dynamic count)**
- Department name
- Count of currently-free officers
- "free of X" total officer count in that department

**Department Workers panel** (department heads only — conditionally rendered)
- List of officers in the head's own department: name, employee ID, Free/Busy indicator, and a Remove action (hidden for the department head's own row).
- A helper line explaining new employees self-register via signup and the department head manages them here.

**Filters bar**
- Free-text search (matches ticket ID or description).
- Status filter (All / Submitted / Assigned / In Progress / Pending Admin Approval / Resolved / Reopened).
- Department filter (All + dynamic list).
- Category filter (All + the 8 category values, see 6.5).
- Assignment filter (Assigned + unassigned / Unassigned only / Assigned only).
- Live "X of Y tickets" count reflecting the active filters.

**Ticket list — one card per ticket, containing:**
- Ticket ID (formatted `JAN-000042`) and category label.
- Status badge (see 6.6 for the exact vocabulary/colors).
- Description text (or "No description provided.").
- Meta row: coordinates, created date/time, priority score, assigned department (or "Pending routing"), assigned worker name + employee ID (or "Not assigned"), estimated completion time (or "Not set").
- **One** of the following conditional action blocks, depending on ticket status/ownership:
  - *Unassigned ticket:* worker-assignment control — dropdown of eligible workers (name, employee ID, current active-ticket count vs. capacity), an "hours to resolve" field labeled "Resolution Time (hrs)", and an Assign button.
  - *Assigned, not yet started, viewed by the assigned worker:* "Officer assigned – work not started yet" + a Start Work button.
  - *In progress, viewed by the assigned worker:* a camera-capture control ("Capture Geo-tag Proof"), the selected filename (or "Camera capture required"), and a Close Ticket button (disabled until a photo is attached).
  - *Pending approval:* a review panel — link/thumbnail to the worker's submitted proof photo, captured timestamp, an optional comment textarea, and Approve & Notify Citizen / Reject & Send Back to Worker buttons.
  - *Resolved, citizen not yet verified:* a confirmation note ("Approved by admin on [date] – waiting for the citizen to confirm") + proof photo link.
  - *Resolved, citizen verified:* a "fully closed" note, the citizen's feedback comment if any, + proof photo link.
  - *Reopened:* a note that the citizen was not satisfied, with their feedback comment if any.
  - *Sent back for rework:* the admin's rejection comment, shown while status is back to in-progress.
- Empty state (no tickets match current filters): a single centered message.

### 6.4 Styling approach (as currently implemented)

- **No CSS framework.** All styling is hand-written plain CSS in a single file, `dashboard/src/index.css` (~580 lines), using semantic class names (`.ticket-card`, `.badge-resolved`, `.filters-bar`, etc.) — not a utility-class system.
- `index.html`'s `<body>` tag carries leftover Tailwind-style utility class names (`bg-slate-950 text-slate-100 font-sans antialiased`) — **these are inert.** Tailwind is not installed (no `tailwind.config`, no PostCSS content pipeline for it) and the actual rendered app is light-themed, not dark — this is a stale leftover from an earlier iteration, not active styling. Worth knowing so it isn't mistaken for the real dark-mode intent.
- **Typeface:** "Inter" is preconnected/loaded from Google Fonts in `index.html` and is the only typeface in use, applied globally via the CSS font stack.
- **Icons:** `lucide-react`, imported per-icon (Bell, Camera, CheckCircle2, Clock, LogOut, MapPin, ShieldCheck, UserMinus, UserPlus, Users, Verified, XCircle are the icons actually in use).
- **Current color system:** light cool-gray background (`#eef3f8`), white cards, a generic corporate blue primary/accent (`#0b63ce`), slate grays for text, and the 6 status badge colors listed in 6.6.
- **Responsive behavior:** a single breakpoint (`max-width: 820px`) collapses several grid layouts to a single column.
- **`leaflet` / `react-leaflet` are installed** and Leaflet's CSS is globally imported, but — see 6.7 — the only component that uses them is not part of the live app. No map currently renders anywhere in the actual dashboard.

### 6.5 Category vocabulary (used in filters and ticket cards)

`pothole`, `garbage_overflow`, `broken_streetlight`, `water_leakage`, `sewage_overflow`, `illegal_dumping`, `damaged_public_property`, `other` — each with a human-readable label already defined in the app (e.g. "Streetlight / Electricity", "Public Property Damage"). All 8 remain valid for filtering/display on this admin dashboard regardless of which categories citizens can currently select when filing a new report.

### 6.6 Status vocabulary (badges)

Exactly six statuses exist today, each with an existing badge color: `submitted`, `assigned`, `in_progress`, `pending_approval`, `resolved`, `reopened`. **There is no seventh "SLA-breached" status in the data model or UI today** — tickets have an `sla_deadline` value, but nothing currently compares it to the current time or renders a distinct visual state for it. Section 5.2 defines a color for this anyway, forward-looking, since the brief asked for one — but the mockup should not invent new UI to display it; only style what's listed in 6.3.

### 6.7 Dead code — not part of the live app (do not use as a design reference)

Four component files exist in `dashboard/src/components/` but are **never imported or rendered** by the live app (`App.jsx` implements everything inline instead): `MetricCards.jsx`, `LiveMap.jsx`, `Leaderboard.jsx`, `ReportList.jsx`. They use a completely different, dark "glassmorphism" visual language (translucent white-on-slate `glass-card` panels, `rgba(255,255,255,0.05)` overlays) that has nothing to do with the actual light-themed app described above. They're flagged here only so they aren't mistaken for the current design or an intended direction — **the redesign should replace what's in Section 6.2–6.3, not restyle or resurrect these files.**

---

## 7. WHAT NOT TO DO

- Do not suggest new features, new data fields, new screens, or changes to what information is shown — Section 6 is the complete, exact scope of content.
- Do not use a literal Indian flag image/graphic as decoration.
- Do not produce a generic "corporate blue admin dashboard" look — that's exactly the generic starting point (see Section 6.4's current palette) this brief is moving away from.
- Do not treat the dead files in Section 6.7 as part of the app to redesign.
