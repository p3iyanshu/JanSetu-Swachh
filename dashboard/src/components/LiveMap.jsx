import React from 'react';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';

export default function LiveMap({ reports }) {
  const center = [13.0827, 77.5877]; // Bangalore coordinates

  return (
    <div className="glass-card" style={{ padding: '16px', borderRadius: '16px', overflow: 'hidden', height: '420px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, margin: 0 }}>Live GIS Geo-Heatmap</h2>
        <span style={{ fontSize: '0.8rem', color: '#10b981', display: 'flex', alignItems: 'center', gap: '6px' }}>
          <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#10b981' }}></span>
          Live Stream
        </span>
      </div>
      <div style={{ height: '350px', borderRadius: '12px', overflow: 'hidden' }}>
        <MapContainer center={center} zoom={13} style={{ height: '100%', width: '100%' }}>
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
          {reports.map((report) => (
            <Marker key={report.id} position={[report.latitude, report.longitude]}>
              <Popup>
                <div style={{ color: '#0f172a' }}>
                  <strong>Ticket #{report.id} ({report.category})</strong>
                  <p style={{ margin: '4px 0' }}>{report.description}</p>
                  <small>Priority Score: {report.priority_score}</small>
                </div>
              </Popup>
            </Marker>
          ))}
        </MapContainer>
      </div>
    </div>
  );
}
