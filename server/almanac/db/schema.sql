CREATE TABLE IF NOT EXISTS workspaces (
  api_key TEXT PRIMARY KEY,
  profile_id TEXT NOT NULL,
  name TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  token TEXT NOT NULL UNIQUE,
  workspace_api_key TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  mode TEXT NOT NULL,
  title TEXT NOT NULL,
  state_json TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  status TEXT NOT NULL DEFAULT 'open',
  created_at TEXT NOT NULL,
  FOREIGN KEY (workspace_api_key) REFERENCES workspaces (api_key)
);

CREATE INDEX IF NOT EXISTS idx_sessions_workspace ON sessions (workspace_api_key);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions (token);

CREATE TABLE IF NOT EXISTS session_clients (
  session_id TEXT NOT NULL,
  client_id TEXT NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  last_seen_at TEXT NOT NULL,
  PRIMARY KEY (session_id, client_id),
  FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS booking_requests (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  slot_id TEXT NOT NULL,
  fields_json TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TEXT NOT NULL,
  FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_booking_requests_session ON booking_requests (session_id);

CREATE TABLE IF NOT EXISTS calendar_snapshots (
  api_key TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  snapshot_json TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (api_key, profile_id),
  FOREIGN KEY (api_key) REFERENCES workspaces (api_key)
);

CREATE TABLE IF NOT EXISTS device_tokens (
  api_key TEXT NOT NULL,
  token TEXT NOT NULL,
  platform TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (api_key, token),
  FOREIGN KEY (api_key) REFERENCES workspaces (api_key)
);

CREATE TABLE IF NOT EXISTS event_locks (
  api_key TEXT NOT NULL,
  event_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  PRIMARY KEY (api_key, event_id),
  FOREIGN KEY (api_key) REFERENCES workspaces (api_key)
);

