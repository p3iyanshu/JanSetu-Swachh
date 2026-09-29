import React, { useEffect, useState } from 'react';
import { CircleMarker, MapContainer, Popup, TileLayer, useMap } from 'react-leaflet';
import { AlertTriangle, Flame, Home, MapPinned, RefreshCw, Recycle, Timer, Trash2 } from 'lucide-react';
import { api } from '../api/client';
import { categoryLabel } from '../lib/categories';

const DEFAULT_CENTER = [13.0827, 77.5877];

const RISK_COLOR = {
  high: '#b3261e',
  medium: '#c8791e',
  low: '#8a6a2f',
};

function formatPercent(value) {
  return value === null || value === undefined ? '—' : `${value}%`;
}

function formatHours(value) {
  return value === null || value === undefined ? '—' : `${value} h`;
}

function formatDate(value) {
  if (!value) return '—';
  return new Date(`${value}Z`).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' });
}

function FitToHotspots({ hotspots }) {
  const map = useMap();
  useEffect(() => {
    if (hotspots.length === 0) return;
    if (hotspots.length === 1) {
      map.setView([hotspots[0].latitude, hotspots[0].longitude], 15);
      return;
    }
    map.fitBounds(
      hotspots.map((spot) => [spot.latitude, spot.longitude]),
      { padding: [40, 40], maxZoom: 15 },
    );
  }, [hotspots, map]);
  return null;
}

function Kpi({ icon: Icon, label, value, hint, tone }) {
  return (
    <div className={`swachh-kpi ${tone || ''}`}>
      <span className="swachh-kpi-label">
        <Icon size={15} /> {label}
      </span>
      <strong>{value}</strong>
      {hint && <span className="swachh-kpi-hint">{hint}</span>}
    </div>
  );
}

function SegregationBar({ segregated, partial, mixed }) {
  const total = segregated + partial + mixed;
  if (total === 0) return <div className="seg-bar empty" />;
  return (
    <div className="seg-bar" role="img" aria-label={`${segregated} segregated, ${partial} partial, ${mixed} mixed`}>
      <span className="seg-good" style={{ width: `${(100 * segregated) / total}%` }} />
      <span className="seg-partial" style={{ width: `${(100 * partial) / total}%` }} />
      <span className="seg-mixed" style={{ width: `${(100 * mixed) / total}%` }} />
    </div>
  );
}

export default function SwachhInsights({ onViewTickets }) {
  const [days, setDays] = useState(30);
  const [summary, setSummary] = useState(null);
  const [hotspots, setHotspots] = useState([]);
  const [segregation, setSegregation] = useState(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function load(period = days) {
    setLoading(true);
    try {
      const [summaryData, hotspotData, segregationData] = await Promise.all([
        api.swachhSummary(period),
        api.swachhHotspots(period),
        api.segregationStats(period),
      ]);
      setSummary(summaryData);
      setHotspots(hotspotData.hotspots);
      setSegregation(segregationData);
      setError('');
    } catch (err) {
      setError(err.message || 'Could not load Swachh insights.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load(days);
    const interval = setInterval(() => load(days), 15000);
    return () => clearInterval(interval);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [days]);

  const maxCategoryTotal = Math.max(1, ...(summary?.by_category || []).map((item) => item.total));

  return (
    <section className="swachh">
      <div className="swachh-toolbar">
        <div>
          <h2>Swachh Insights</h2>
          <p>Waste segregation, disposal and sanitation across all wards.</p>
        </div>
        <div className="swachh-toolbar-actions">
          <select value={days} onChange={(e) => setDays(Number(e.target.value))} aria-label="Time period">
            <option value={7}>Last 7 days</option>
            <option value={30}>Last 30 days</option>
            <option value={90}>Last 90 days</option>
          </select>
          <button type="button" className="ghost" onClick={() => load(days)} disabled={loading}>
            <RefreshCw size={16} className={loading ? 'spin' : ''} /> Refresh
          </button>
        </div>
      </div>

      {error && <div className="error">{error}</div>}

      <div className="swachh-kpis">
        <Kpi
          icon={Trash2}
          label="Open waste & sanitation"
          value={summary ? summary.open : '—'}
          hint={summary ? `${summary.total} reported in period` : null}
        />
        <Kpi
          icon={AlertTriangle}
          label="Past SLA, still open"
          value={summary ? summary.overdue : '—'}
          tone={summary?.overdue ? 'warn' : ''}
        />
        <Kpi
          icon={Timer}
          label="Avg clearance time"
          value={formatHours(summary?.avg_clearance_hours)}
          hint={summary ? `${formatPercent(summary.resolved_within_sla_rate)} cleared within SLA` : null}
        />
        <Kpi
          icon={Recycle}
          label="Households segregating"
          value={formatPercent(segregation?.segregation_rate)}
          hint={segregation ? `${segregation.households} households · ${segregation.visits} visits` : null}
          tone="good"
        />
        <Kpi
          icon={Flame}
          label="Recurring hotspots"
          value={hotspots.length}
          hint={`${hotspots.filter((spot) => spot.risk === 'high').length} high risk`}
          tone={hotspots.some((spot) => spot.risk === 'high') ? 'warn' : ''}
        />
      </div>

      <div className="swachh-grid">
        <div className="swachh-panel swachh-map-panel">
          <h3><MapPinned size={18} /> Garbage hotspots</h3>
          <p className="panel-hint">
            Spots where waste complaints keep coming back (2+ reports within 150 m). Plan preventive cleanups, bins
            or CCTV here.
          </p>
          <div className="swachh-map">
            <MapContainer center={DEFAULT_CENTER} zoom={12} scrollWheelZoom={false}>
              <TileLayer
                attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              />
              <FitToHotspots hotspots={hotspots} />
              {hotspots.map((spot) => (
                <CircleMarker
                  key={spot.report_ids.join('-')}
                  center={[spot.latitude, spot.longitude]}
                  radius={8 + Math.min(spot.report_count, 10) * 2}
                  pathOptions={{
                    color: RISK_COLOR[spot.risk],
                    fillColor: RISK_COLOR[spot.risk],
                    fillOpacity: 0.35,
                    weight: 2,
                  }}
                >
                  <Popup>
                    <strong>{spot.report_count} reports · {spot.risk} risk</strong>
                    <br />
                    {spot.open_count} still open
                    <br />
                    Last reported {formatDate(spot.last_reported_at)}
                    <br />
                    <button type="button" className="link-button" onClick={() => onViewTickets(spot.report_ids)}>
                      View these tickets
                    </button>
                  </Popup>
                </CircleMarker>
              ))}
            </MapContainer>
          </div>
        </div>

        <div className="swachh-panel">
          <h3><Flame size={18} /> Top hotspots</h3>
          {hotspots.length === 0 ? (
            <p className="panel-empty">No recurring hotspots in this period.</p>
          ) : (
            <ol className="hotspot-list">
              {hotspots.slice(0, 8).map((spot) => (
                <li key={spot.report_ids.join('-')}>
                  <span className={`risk-dot risk-${spot.risk}`} aria-hidden="true" />
                  <div>
                    <strong>
                      {spot.report_count} reports · <span className={`risk-text risk-${spot.risk}`}>{spot.risk} risk</span>
                    </strong>
                    <span>
                      {Object.entries(spot.categories)
                        .map(([category, count]) => `${categoryLabel[category] || category} ×${count}`)
                        .join(', ')}
                    </span>
                    <span className="mono">
                      {spot.latitude.toFixed(4)}, {spot.longitude.toFixed(4)} · {spot.open_count} open
                    </span>
                  </div>
                  <button type="button" className="ghost small" onClick={() => onViewTickets(spot.report_ids)}>
                    Tickets
                  </button>
                </li>
              ))}
            </ol>
          )}
        </div>
      </div>

      <div className="swachh-grid">
        <div className="swachh-panel">
          <h3><Recycle size={18} /> Segregation compliance by ward</h3>
          <p className="panel-hint">
            From door-to-door collection rounds logged by sanitation workers. Rate = segregated ÷ households that
            handed over waste.
          </p>
          {!segregation || segregation.wards.length === 0 ? (
            <p className="panel-empty">No collection rounds logged in this period yet.</p>
          ) : (
            <>
              <table className="ward-table">
                <thead>
                  <tr>
                    <th>Ward</th>
                    <th>Households</th>
                    <th>Segregated · Partial · Mixed</th>
                    <th>Rate</th>
                  </tr>
                </thead>
                <tbody>
                  {segregation.wards.map((ward) => (
                    <tr key={ward.ward}>
                      <td>{ward.ward}</td>
                      <td>{ward.households}</td>
                      <td>
                        <SegregationBar segregated={ward.segregated} partial={ward.partial} mixed={ward.mixed} />
                        <span className="seg-counts">
                          {ward.segregated} · {ward.partial} · {ward.mixed}
                        </span>
                      </td>
                      <td>
                        <strong className={ward.segregation_rate !== null && ward.segregation_rate < 50 ? 'rate-low' : 'rate-ok'}>
                          {formatPercent(ward.segregation_rate)}
                        </strong>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <div className="seg-legend">
                <span><i className="seg-good" /> Segregated</span>
                <span><i className="seg-partial" /> Partial</span>
                <span><i className="seg-mixed" /> Mixed</span>
              </div>
            </>
          )}
        </div>

        <div className="swachh-panel">
          <h3><Home size={18} /> Households needing follow-up</h3>
          <p className="panel-hint">Handed over mixed waste on 2+ visits — target for awareness drives or notices.</p>
          {!segregation || segregation.repeat_offenders.length === 0 ? (
            <p className="panel-empty">No repeat mixed-waste households in this period.</p>
          ) : (
            <>
              <ul className="offender-list">
                {segregation.repeat_offenders.slice(0, 8).map((item) => (
                  <li key={`${item.ward}-${item.household_code}`}>
                    <span className="mono">{item.household_code}</span>
                    <span>{item.ward}</span>
                    <b>{item.mixed_count}× mixed</b>
                  </li>
                ))}
              </ul>
              {segregation.repeat_offenders.length > 8 && (
                <p className="list-more">
                  +{segregation.repeat_offenders.length - 8} more households with repeated mixed waste
                </p>
              )}
            </>
          )}
        </div>
      </div>

      <div className="swachh-panel">
        <h3><Trash2 size={18} /> Complaints by type</h3>
        {!summary || summary.total === 0 ? (
          <p className="panel-empty">No waste or sanitation complaints in this period.</p>
        ) : (
          <div className="category-bars">
            {summary.by_category.map((item) => (
              <div key={item.category} className="category-bar-row">
                <span>{categoryLabel[item.category] || item.category}</span>
                <div className="category-bar-track">
                  <span
                    className="category-bar-resolved"
                    style={{ width: `${(100 * item.resolved) / maxCategoryTotal}%` }}
                  />
                  <span
                    className="category-bar-open"
                    style={{ width: `${(100 * (item.total - item.resolved)) / maxCategoryTotal}%` }}
                  />
                </div>
                <b>{item.total}</b>
              </div>
            ))}
            <div className="seg-legend">
              <span><i className="seg-good" /> Resolved</span>
              <span><i className="category-open-swatch" /> Not yet resolved</span>
            </div>
          </div>
        )}
      </div>
    </section>
  );
}
