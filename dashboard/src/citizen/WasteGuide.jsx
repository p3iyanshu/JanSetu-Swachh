import React, { useEffect, useMemo, useState } from 'react';
import { Search } from 'lucide-react';
import { api } from '../api/client';

/** "Which Bin?" - four-stream household segregation guide (SWM Rules 2026). */
export default function WasteGuide() {
  const [guide, setGuide] = useState(null);
  const [error, setError] = useState('');
  const [query, setQuery] = useState('');
  const [stream, setStream] = useState('all');

  useEffect(() => {
    api.wasteGuide().then(setGuide).catch((err) => setError(err.message));
  }, []);

  const streamsById = useMemo(
    () => Object.fromEntries((guide?.streams || []).map((item) => [item.id, item])),
    [guide],
  );

  const items = useMemo(() => {
    const needle = query.trim().toLowerCase();
    return (guide?.items || []).filter((item) => {
      if (stream !== 'all' && item.stream !== stream) return false;
      if (!needle) return true;
      return item.name.toLowerCase().includes(needle) || streamsById[item.stream]?.name.toLowerCase().includes(needle);
    });
  }, [guide, query, stream, streamsById]);

  if (error) return <div className="error">{error}</div>;
  if (!guide) return <p className="empty-state">Loading the guide...</p>;

  return (
    <section className="guide">
      <div className="guide-intro">
        Segregate at source into four streams. Mixed waste can't be recycled or composted - it ends up in landfills.
      </div>
      <div className="stream-grid">
        {guide.streams.map((item) => (
          <article key={item.id} className="stream-card" style={{ '--stream': item.color }}>
            <h3>{item.name}</h3>
            <span className="stream-bin">{item.bin}</span>
            <p>{item.summary}</p>
            <p className="stream-goes">Goes to: {item.goes_to}</p>
            <ul>
              {item.tips.map((tip) => <li key={tip}>{tip}</li>)}
            </ul>
          </article>
        ))}
      </div>

      <div className="guide-search">
        <div className="search-input">
          <Search size={16} />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search an item, e.g. battery, milk packet, diaper"
            aria-label="Search waste items"
          />
        </div>
        <select value={stream} onChange={(e) => setStream(e.target.value)} aria-label="Filter by stream">
          <option value="all">All streams</option>
          {guide.streams.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
        </select>
      </div>

      <div className="item-grid">
        {items.map((item) => {
          const itemStream = streamsById[item.stream];
          return (
            <div key={item.name} className="item-row" style={{ '--stream': itemStream?.color }}>
              <div>
                <strong>{item.name}</strong>
                <span>{item.tip}</span>
              </div>
              <b className="item-stream">{itemStream?.name.replace(' Waste', '')}</b>
            </div>
          );
        })}
        {items.length === 0 && (
          <p className="empty-state">No match. When unsure, keep it separate and ask your waste collector.</p>
        )}
      </div>
      <p className="guide-source">Source: {guide.source}</p>
    </section>
  );
}
