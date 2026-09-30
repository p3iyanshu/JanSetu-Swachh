import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import { loadRemoteConfig } from './api/client';
import './index.css';
import './portal.css';

// Learn the current backend address before the first request.
loadRemoteConfig().finally(() => {
  ReactDOM.createRoot(document.getElementById('root')).render(
    <React.StrictMode>
      <App />
    </React.StrictMode>,
  );
});
