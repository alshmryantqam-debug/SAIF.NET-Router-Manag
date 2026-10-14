
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS companies (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'suspended')),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    email TEXT NOT NULL COLLATE NOCASE,
    display_name TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL
        CHECK (role IN ('owner', 'admin', 'technician', 'billing', 'viewer')),
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'disabled')),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(company_id, email),
    FOREIGN KEY(company_id) REFERENCES companies(id)
);

CREATE TABLE IF NOT EXISTS sessions (
    id_hash TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS routers (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    name TEXT NOT NULL,
    host_label TEXT,
    model TEXT,
    routeros_version TEXT,
    connection_type TEXT NOT NULL DEFAULT 'pending'
        CHECK (connection_type IN ('pending', 'private_agent', 'wireguard', 'rest_api')),
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'online', 'offline', 'error')),
    last_seen_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY(company_id) REFERENCES companies(id)
);

CREATE TABLE IF NOT EXISTS router_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    company_id TEXT NOT NULL,
    router_id TEXT NOT NULL,
    cpu_percent REAL,
    memory_percent REAL,
    temperature_c REAL,
    latency_ms REAL,
    packet_loss_percent REAL,
    rx_bytes_per_second REAL,
    tx_bytes_per_second REAL,
    sampled_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY(company_id) REFERENCES companies(id),
    FOREIGN KEY(router_id) REFERENCES routers(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS plans (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    name TEXT NOT NULL,
    download_kbps INTEGER NOT NULL CHECK (download_kbps > 0),
    upload_kbps INTEGER NOT NULL CHECK (upload_kbps > 0),
    price_minor INTEGER NOT NULL DEFAULT 0 CHECK (price_minor >= 0),
    currency TEXT NOT NULL DEFAULT 'USD',
    duration_days INTEGER NOT NULL DEFAULT 30 CHECK (duration_days > 0),
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'archived')),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY(company_id) REFERENCES companies(id)
);

CREATE TABLE IF NOT EXISTS subscribers (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    router_id TEXT,
    plan_id TEXT,
    username TEXT NOT NULL,
    full_name TEXT,
    phone TEXT,
    service_type TEXT NOT NULL
        CHECK (service_type IN ('pppoe', 'hotspot', 'static')),
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('active', 'suspended', 'pending', 'expired')),
    starts_at TEXT,
    expires_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(company_id, username),
    FOREIGN KEY(company_id) REFERENCES companies(id),
    FOREIGN KEY(router_id) REFERENCES routers(id),
    FOREIGN KEY(plan_id) REFERENCES plans(id)
);

CREATE TABLE IF NOT EXISTS invoices (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    subscriber_id TEXT NOT NULL,
    amount_minor INTEGER NOT NULL CHECK (amount_minor >= 0),
    currency TEXT NOT NULL DEFAULT 'USD',
    status TEXT NOT NULL DEFAULT 'unpaid'
        CHECK (status IN ('unpaid', 'paid', 'void', 'overdue')),
    due_at TEXT,
    paid_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY(company_id) REFERENCES companies(id),
    FOREIGN KEY(subscriber_id) REFERENCES subscribers(id)
);

CREATE TABLE IF NOT EXISTS audit_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    company_id TEXT NOT NULL,
    actor_user_id TEXT,
    action TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id TEXT,
    details_json TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY(company_id) REFERENCES companies(id),
    FOREIGN KEY(actor_user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_users_company
    ON users(company_id);

CREATE INDEX IF NOT EXISTS idx_sessions_expiry
    ON sessions(expires_at);

CREATE INDEX IF NOT EXISTS idx_routers_company
    ON routers(company_id);

CREATE INDEX IF NOT EXISTS idx_metrics_router_time
    ON router_metrics(router_id, sampled_at);

CREATE INDEX IF NOT EXISTS idx_subscribers_company_status
    ON subscribers(company_id, status);

CREATE INDEX IF NOT EXISTS idx_invoices_company_status
    ON invoices(company_id, status);

CREATE INDEX IF NOT EXISTS idx_audit_company_time
    ON audit_events(company_id, created_at);
