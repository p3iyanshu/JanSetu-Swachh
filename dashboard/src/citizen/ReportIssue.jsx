import React, { useEffect, useRef, useState } from 'react';
import { CircleMarker, MapContainer, TileLayer, useMap, useMapEvents } from 'react-leaflet';
import { Camera, CheckCircle2, Crosshair, ImagePlus, Loader2, Sparkles } from 'lucide-react';
import { api } from '../api/client';
import { CITIZEN_CATEGORIES } from '../lib/categories';
import { ticketCode } from '../lib/format';

const DEFAULT_LOCATION = { lat: 13.0827, lng: 77.5877 }; // Bengaluru

function ClickToPlace({ onPick }) {
  useMapEvents({ click: (event) => onPick({ lat: event.latlng.lat, lng: event.latlng.lng }) });
  return null;
}

function FollowLocation({ location }) {
  const map = useMap();
  useEffect(() => {
    map.setView([location.lat, location.lng], Math.max(map.getZoom(), 15));
  }, [location.lat, location.lng, map]);
  return null;
}

function CategoryGroup({ title, group, tone, value, onChange }) {
  return (
    <div className="category-group">
      <h4 className={`category-group-title ${tone}`}>{title}</h4>
      <div className="category-choices">
        {CITIZEN_CATEGORIES.filter((item) => item.group === group).map((item) => (
          <button
            key={item.id}
            type="button"
            className={`category-choice ${tone} ${value === item.id ? 'active' : ''}`}
            aria-pressed={value === item.id}
            onClick={() => onChange(item.id)}
          >
            <strong>{item.label}</strong>
            <span>{item.hint}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

export default function ReportIssue({ userId, initialCategory, onSubmitted }) {
  const [category, setCategory] = useState(initialCategory || '');
  const [categoryChosen, setCategoryChosen] = useState(Boolean(initialCategory));
  const [photo, setPhoto] = useState(null);
  const [preview, setPreview] = useState(null);
  const [aiMessage, setAiMessage] = useState(null);
  const [location, setLocation] = useState(DEFAULT_LOCATION);
  const [locationNote, setLocationNote] = useState('Click the map to mark the exact spot, or use your current location.');
  const [description, setDescription] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [created, setCreated] = useState(null);
  const fileInput = useRef(null);

  useEffect(() => {
    setCategory(initialCategory || '');
    setCategoryChosen(Boolean(initialCategory));
  }, [initialCategory]);

  useEffect(() => () => preview && URL.revokeObjectURL(preview), [preview]);

  function chooseCategory(id) {
    setCategory(id);
    setCategoryChosen(true);
  }

  async function onPhotoSelected(event) {
    const file = event.target.files?.[0];
    if (!file) return;
    setPhoto(file);
    setPreview(URL.createObjectURL(file));
    setError('');
    setAiMessage({ loading: true, text: 'Checking the photo with AI...' });
    try {
      const result = await api.analyzeIssue(file);
      const known = CITIZEN_CATEGORIES.find((item) => item.id === result.category);
      if (result.detected && known) {
        if (categoryChosen && category !== known.id) {
          setAiMessage({ text: `AI thinks this looks like ${known.label}. Keeping your choice.` });
        } else {
          setCategory(known.id);
          setAiMessage({ text: `AI detected ${known.label}. You can change it.` });
        }
      } else {
        setAiMessage({ text: 'AI could not confidently detect the issue type - please choose it.' });
      }
    } catch {
      setAiMessage({ text: 'AI suggestion unavailable - please choose the issue type.' });
    }
  }

  function useMyLocation() {
    if (!navigator.geolocation) {
      setLocationNote('This browser cannot share location - click the map instead.');
      return;
    }
    setLocationNote('Getting your location...');
    navigator.geolocation.getCurrentPosition(
      (position) => {
        setLocation({ lat: position.coords.latitude, lng: position.coords.longitude });
        setLocationNote('Using your current location. Click the map to adjust.');
      },
      () => setLocationNote('Location permission denied or unavailable - click the map to mark the spot.'),
      { enableHighAccuracy: true, timeout: 10000 },
    );
  }

  async function submit(event) {
    event.preventDefault();
    setError('');
    if (!photo) return setError('Add a photo of the issue - it is the "before" proof for the fix.');
    if (!category) return setError('Select the issue type.');
    setBusy(true);
    try {
      const { photo_url: photoUrl } = await api.uploadPhoto(photo);
      const label = CITIZEN_CATEGORIES.find((item) => item.id === category)?.label || 'Issue';
      const report = await api.createReport({
        photo_url: photoUrl,
        latitude: location.lat,
        longitude: location.lng,
        category,
        description: description.trim() || `${label} reported by citizen.`,
        user_id: userId,
      });
      setCreated(report);
      onSubmitted?.(report);
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  function reset() {
    setCreated(null);
    setPhoto(null);
    setPreview(null);
    setAiMessage(null);
    setDescription('');
    setCategory('');
    setCategoryChosen(false);
    if (fileInput.current) fileInput.current.value = '';
  }

  if (created) {
    return (
      <section className="portal-panel success-panel">
        <CheckCircle2 size={44} />
        <h3>Ticket {ticketCode(created.id)} created</h3>
        <p>
          Routed to <b>{created.assigned_department_name || 'the concerned department'}</b>. You can follow its progress
          under <b>My Tickets</b>.
        </p>
        <button type="button" className="primary" onClick={reset}>Report another issue</button>
      </section>
    );
  }

  return (
    <form className="portal-panel report-form" onSubmit={submit}>
      <div className="report-grid">
        <div>
          <h3 className="panel-title">1. Photo of the issue</h3>
          <label className={`photo-drop ${preview ? 'has-photo' : ''}`}>
            {preview ? (
              <img src={preview} alt="Selected issue" />
            ) : (
              <>
                <ImagePlus size={36} />
                <strong>Add a photo</strong>
                <span>Required - it's the "before" proof for the cleanup</span>
              </>
            )}
            <input ref={fileInput} type="file" accept="image/*" capture="environment" onChange={onPhotoSelected} />
          </label>
          {preview && (
            <button type="button" className="ghost small" onClick={() => fileInput.current?.click()}>
              <Camera size={14} /> Change photo
            </button>
          )}
          {aiMessage && (
            <p className="ai-note">
              {aiMessage.loading ? <Loader2 size={14} className="spin" /> : <Sparkles size={14} />} {aiMessage.text}
            </p>
          )}

          <h3 className="panel-title">3. Location</h3>
          <div className="location-map">
            <MapContainer center={[location.lat, location.lng]} zoom={13} scrollWheelZoom>
              <TileLayer
                attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              />
              <ClickToPlace
                onPick={(next) => {
                  setLocation(next);
                  setLocationNote('Spot marked on the map.');
                }}
              />
              <FollowLocation location={location} />
              <CircleMarker
                center={[location.lat, location.lng]}
                radius={10}
                pathOptions={{ color: '#b3261e', fillColor: '#b3261e', fillOpacity: 0.5 }}
              />
            </MapContainer>
          </div>
          <div className="location-row">
            <span className="mono">{location.lat.toFixed(5)}, {location.lng.toFixed(5)}</span>
            <button type="button" className="ghost small" onClick={useMyLocation}>
              <Crosshair size={14} /> Use my location
            </button>
          </div>
          <p className="panel-hint">{locationNote}</p>
        </div>

        <div>
          <h3 className="panel-title">2. What's the problem?</h3>
          <CategoryGroup title="Waste & Sanitation (Swachh)" group="swachh" tone="green" value={category} onChange={chooseCategory} />
          <CategoryGroup title="Other civic issues" group="civic" tone="blue" value={category} onChange={chooseCategory} />

          <h3 className="panel-title">4. Details (optional)</h3>
          <textarea
            className="text-area"
            rows={4}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="e.g. Garbage has not been cleared for 3 days near the bus stop"
          />

          {error && <div className="error">{error}</div>}
          <button type="submit" className="primary report-submit" disabled={busy}>
            {busy ? 'Submitting...' : 'Submit report'}
          </button>
        </div>
      </div>
    </form>
  );
}
