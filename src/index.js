// =====================================================================
// SAIF.NET Router Manager — Cloudflare Worker
// =====================================================================

const json = (data, status = 200, extraHeaders = {}) =>
  new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
      "Referrer-Policy": "no-referrer",
      ...extraHeaders
    }
  });

const cookieName = "__Host-saif_session";
const sessionSeconds = 24 * 60 * 60;
const sessionRenewThreshold = 6 * 60 * 60;
const maxBodyBytes = 16 * 1024;

const exposedSetupSecret = "SAIF-NET-Setup-9vK4mR7xQ2pL8wT6zB5nH3cF";
const isSafeSetupSecret = value =>
  typeof value === "string" && value.length >= 32 && value !== exposedSetupSecret;

function readCookie(request, name) {
  const cookies = request.headers.get("Cookie") || "";
  for (const part of cookies.split(";")) {
    const index = part.indexOf("=");
    if (index < 0) continue;
    if (part.slice(0, index).trim() === name) {
      return part.slice(index + 1).trim();
    }
  }
  return null;
}

function readBearer(request) {
  const header = request.headers.get("Authorization") || "";
  if (header.startsWith("Bearer ")) return header.slice(7).trim();
  return null;
}

function readSessionToken(request) {
  return readCookie(request, cookieName) || readBearer(request);
}

function sessionCookie(token, maxAge) {
  return `${cookieName}=${token}; Path=/; Max-Age=${maxAge}; HttpOnly; Secure; SameSite=Strict`;
}

async function sha256(value) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value)
  );
  return [...new Uint8Array(digest)]
    .map(b => b.toString(16).padStart(2, "0"))
    .join("");
}

function constantTimeEqual(a, b) {
  if (typeof a !== "string" || typeof b !== "string") return false;
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

async function hashPassword(password, saltBytes) {
  const salt = saltBytes || crypto.getRandomValues(new Uint8Array(16));
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(password),
    "PBKDF2",
    false,
    ["deriveBits"]
  );
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", hash: "SHA-256", salt, iterations: 310000 },
    key,
    256
  );
  const hex = bytes =>
    [...new Uint8Array(bytes)]
      .map(b => b.toString(16).padStart(2, "0"))
      .join("");
  return `pbkdf2$310000$${hex(salt)}$${hex(bits)}`;
}

async function verifyPassword(password, stored) {
  try {
    const [algorithm, rounds, saltHex, expected] = stored.split("$");
    if (algorithm !== "pbkdf2" || rounds !== "310000") return false;
    const salt = new Uint8Array(saltHex.match(/.{2}/g).map(x => parseInt(x, 16)));
    const actual = await hashPassword(password, salt);
    const actualHash = actual.split("$")[3];
    return constantTimeEqual(actualHash, expected);
  } catch {
    return false;
  }
}

async function bodyJsonLimited(request, maxBytes = maxBodyBytes) {
  try {
    const reader = request.body?.getReader();
    if (!reader) return null;
    const chunks = [];
    let total = 0;
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > maxBytes) return null;
      chunks.push(value);
    }
    const buf = new Uint8Array(total);
    let offset = 0;
    for (const c of chunks) { buf.set(c, offset); offset += c.byteLength; }
    return JSON.parse(new TextDecoder().decode(buf));
  } catch {
    return null;
  }
}

function validPassword(password) {
  return typeof password === "string" &&
    password.length >= 12 &&
    password.length <= 128;
}// ---------------------------------------------------------------------
// Rate limiting (in-memory)
// ---------------------------------------------------------------------
const loginFailures = new Map();
const LOGIN_WINDOW_MS = 15 * 60 * 1000;
const LOGIN_MAX_FAILURES = 10;

function loginRateCheck(key) {
  const now = Date.now();
  const arr = (loginFailures.get(key) || []).filter(t => now - t < LOGIN_WINDOW_MS);
  loginFailures.set(key, arr);
  return arr.length < LOGIN_MAX_FAILURES;
}

function loginRateRecord(key) {
  const now = Date.now();
  const arr = (loginFailures.get(key) || []).filter(t => now - t < LOGIN_WINDOW_MS);
  arr.push(now);
  loginFailures.set(key, arr);
}

function loginRateClear(key) {
  loginFailures.delete(key);
}

// ---------------------------------------------------------------------
// Audit log — best-effort
// ---------------------------------------------------------------------
async function writeAudit(env, { companyId, userId, eventType, meta }) {
  try {
    await env.DB.prepare(`
      INSERT INTO audit_events
        (id, company_id, actor_user_id, action, resource_type, resource_id, metadata, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).bind(
      crypto.randomUUID(),
      companyId || null,
      userId || null,
      eventType,
      "session",
      null,
      JSON.stringify(meta || {}),
      new Date().toISOString()
    ).run();
  } catch {
    // never fail a request because of audit failure
  }
}

// ---------------------------------------------------------------------
// currentUser — cookie OR bearer
// ---------------------------------------------------------------------
async function currentUser(request, env) {
  const token = readSessionToken(request);
  if (!token || !env.DB) return null;

  const idHash = await sha256(token);
  const row = await env.DB.prepare(`
    SELECT u.id, u.company_id, u.email, u.display_name, u.role,
           u.status AS user_status,
           c.name AS company_name,
           s.expires_at, s.id_hash
    FROM sessions s
    JOIN users u ON u.id = s.user_id
    JOIN companies c ON c.id = u.company_id
    WHERE s.id_hash = ?
  `).bind(idHash).first();

  if (!row) return null;
  if (row.user_status !== "active") return null;

  const expires = Date.parse(row.expires_at);
  if (!Number.isFinite(expires) || expires <= Date.now()) {
    await env.DB.prepare("DELETE FROM sessions WHERE id_hash = ?")
      .bind(idHash).run();
    return null;
  }

  const remaining = expires - Date.now();
  if (remaining < sessionRenewThreshold * 1000) {
    const newExpiry = new Date(Date.now() + sessionSeconds * 1000).toISOString();
    await env.DB.prepare("UPDATE sessions SET expires_at = ? WHERE id_hash = ?")
      .bind(newExpiry, idHash).run();
  }

  return row;
}

// ---------------------------------------------------------------------
// Origin check — allow native clients (no Origin) but forbid CSRF via cookie
// ---------------------------------------------------------------------
function safeOriginOrNative(request) {
  const origin = request.headers.get("Origin");
  if (!origin) return { ok: true, native: true };
  try {
    return { ok: new URL(origin).origin === new URL(request.url).origin, native: false };
  } catch {
    return { ok: false, native: false };
  }
}

// ---------------------------------------------------------------------
// MikroTik REST helpers (read-only)
// ---------------------------------------------------------------------
async function decryptSecret(encB64, keyB64) {
  try {
    const keyBytes = Uint8Array.from(atob(keyB64), c => c.charCodeAt(0));
    if (keyBytes.length !== 32) return null;
    const key = await crypto.subtle.importKey(
      "raw", keyBytes, "AES-GCM", false, ["decrypt"]
    );
    const enc = Uint8Array.from(atob(encB64), c => c.charCodeAt(0));
    const iv = enc.slice(0, 12);
    const ciphertext = enc.slice(12);
    const plaintext = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv }, key, ciphertext
    );
    return new TextDecoder().decode(plaintext);
  } catch {
    return null;
  }
}

async function fetchMikroTikJson(url, headers, timeoutMs = 8000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { headers, signal: controller.signal });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } finally {
    clearTimeout(timer);
  }
}

async function fetchRouterMetrics(router, env) {
  const password = await decryptSecret(router.api_password_enc, env.ROUTER_SECRET_KEY);
  if (!password) throw new Error("Credentials could not be decrypted");

  const base = router.api_endpoint.replace(/\/$/, "");
  const headers = {
    "Authorization": "Basic " + btoa(`${router.api_username}:${password}`),
    "Accept": "application/json"
  };
  if (env.CF_ACCESS_CLIENT_ID) headers["CF-Access-Client-Id"] = env.CF_ACCESS_CLIENT_ID;
  if (env.CF_ACCESS_CLIENT_SECRET) headers["CF-Access-Client-Secret"] = env.CF_ACCESS_CLIENT_SECRET;

  const [resource, health, identity] = await Promise.all([
    fetchMikroTikJson(`${base}/rest/system/resource`, headers),
    fetchMikroTikJson(`${base}/rest/system/health`, headers).catch(() => []),
    fetchMikroTikJson(`${base}/rest/system/identity`, headers).catch(() => ({}))
  ]);

  const healthMap = {};
  if (Array.isArray(health)) {
    for (const h of health) healthMap[h.name] = h.value;
  }

  return {
    source: "live",
    identity: identity?.name || null,
    boardName: resource["board-name"] || null,
    version: resource.version || null,
    uptime: resource.uptime || null,
    cpuLoad: Number(resource["cpu-load"] ?? NaN),
    cpuCount: Number(resource["cpu-count"] ?? NaN),
    memoryTotal: Number(resource["total-memory"] ?? NaN),
    memoryFree: Number(resource["free-memory"] ?? NaN),
    temperature: healthMap.temperature != null ? Number(healthMap.temperature) : null,
    voltage: healthMap.voltage != null ? Number(healthMap.voltage) : null,
    fetchedAt: new Date().toISOString()
  };
    }// =====================================================================
// Main fetch handler
// =====================================================================
export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    try {
      if (!url.pathname.startsWith("/api/")) {
        if (env.ASSETS) return env.ASSETS.fetch(request);
        return new Response("SAIF.NET service unavailable", { status: 503 });
      }

      if (!env.DB) {
        return json({ error: "Database unavailable" }, 503);
      }

      // ---- GET /api/health ----
      if (url.pathname === "/api/health" && request.method === "GET") {
        await env.DB.prepare("SELECT 1 AS ok").first();
        return json({
          service: "SAIF.NET",
          status: "online",
          api: "ready",
          databaseConfigured: true,
          mikrotikConfigured: Boolean(env.ROUTER_SECRET_KEY),
          cfAccessConfigured: Boolean(env.CF_ACCESS_CLIENT_ID && env.CF_ACCESS_CLIENT_SECRET)
        });
      }

      // ---- GET /api/setup/status ----
      if (url.pathname === "/api/setup/status" && request.method === "GET") {
        const existing = await env.DB.prepare(
          "SELECT COUNT(*) AS total FROM users"
        ).first();
        return json({
          setupRequired: Number(existing?.total || 0) === 0,
          setupConfigured: isSafeSetupSecret(env.SETUP_SECRET)
        });
      }

      // ---- Origin check for mutating methods ----
      if (request.method === "POST" || request.method === "PUT" ||
          request.method === "PATCH" || request.method === "DELETE") {
        const origin = safeOriginOrNative(request);
        if (!origin.ok) {
          return json({ error: "Invalid request origin" }, 403);
        }
        if (origin.native && readCookie(request, cookieName)) {
          return json({ error: "Invalid request origin" }, 403);
        }
      }

      // ---- POST /api/setup ----
      if (url.pathname === "/api/setup" && request.method === "POST") {
        if (!isSafeSetupSecret(env.SETUP_SECRET)) {
          return json({ error: "Rotate SETUP_SECRET in Cloudflare before initial setup" }, 503);
        }

        const body = await bodyJsonLimited(request);
        if (!body || typeof body.secret !== "string") {
          return json({ error: "Invalid request" }, 400);
        }

        if (!constantTimeEqual(body.secret, env.SETUP_SECRET)) {
          await writeAudit(env, {
            eventType: "setup_failed_secret",
            meta: { ip: request.headers.get("CF-Connecting-IP") || null }
          });
          return json({ error: "Forbidden" }, 403);
        }

        const existing = await env.DB.prepare(
          "SELECT COUNT(*) AS total FROM users"
        ).first();
        if (Number(existing?.total || 0) !== 0) {
          return json({ error: "Initial setup already completed" }, 409);
        }

        const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
        const password = body.password;
        const displayName = typeof body.displayName === "string" ? body.displayName.trim() : "";
        const companyName = typeof body.companyName === "string" ? body.companyName.trim() : "";

        if (
          !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
          email.length > 254 ||
          !validPassword(password) ||
          !displayName || displayName.length > 100 ||
          !companyName || companyName.length > 120
        ) {
          return json({ error: "Check email, password (12-128 chars), name and company" }, 400);
        }

        const existingEmail = await env.DB.prepare(
          "SELECT id FROM users WHERE email = ? COLLATE NOCASE LIMIT 1"
        ).bind(email).first();
        if (existingEmail) {
          return json({ error: "An account with this email already exists" }, 409);
        }

        const companyId = crypto.randomUUID();
        const userId = crypto.randomUUID();
        const slug = `saif-${crypto.randomUUID()}`;
        const passwordHash = await hashPassword(password);

        await env.DB.batch([
          env.DB.prepare(`
            INSERT INTO companies (id, name, slug)
            SELECT ?, ?, ?
            WHERE NOT EXISTS (SELECT 1 FROM users)
          `).bind(companyId, companyName, slug),
          env.DB.prepare(`
            INSERT INTO users
              (id, company_id, email, display_name, password_hash, role)
            SELECT ?, ?, ?, ?, ?, 'owner'
            WHERE EXISTS (SELECT 1 FROM companies WHERE id = ?)
              AND NOT EXISTS (SELECT 1 FROM users)
          `).bind(userId, companyId, email, displayName, passwordHash, companyId)
        ]);

        const created = await env.DB.prepare(
          "SELECT id FROM users WHERE id = ?"
        ).bind(userId).first();
        if (!created) {
          return json({ error: "Initial setup already completed" }, 409);
        }

        await writeAudit(env, {
          companyId, userId, eventType: "setup_owner_created",
          meta: { email }
        });

        return json({
          status: "created",
          message: "Owner account created. You can now sign in."
        }, 201);
      }

      // ---- POST /api/login ----
      if (url.pathname === "/api/login" && request.method === "POST") {
        const body = await bodyJsonLimited(request);
        if (!body || typeof body.email !== "string" || typeof body.password !== "string") {
          return json({ error: "Invalid email or password" }, 400);
        }

        const email = body.email.trim().toLowerCase();
        if (email.length > 254 || body.password.length > 128) {
          return json({ error: "Invalid email or password" }, 400);
        }

        const clientIp = request.headers.get("CF-Connecting-IP") || "unknown";
        const rateKey = `${clientIp}|${email}`;

        if (!loginRateCheck(rateKey)) {
          await writeAudit(env, {
            eventType: "login_rate_limited",
            meta: { email, ip: clientIp }
          });
          return json({ error: "Too many attempts. Try again later." }, 429);
        }

        const matches = await env.DB.prepare(`
          SELECT id, company_id, email, display_name, password_hash, role, status
          FROM users WHERE email = ? COLLATE NOCASE LIMIT 2
        `).bind(email).all();

        const candidates = matches.results || [];
        const user = candidates.length === 1 ? candidates[0] : null;

        if (
          !user ||
          user.status !== "active" ||
          !(await verifyPassword(body.password, user.password_hash))
        ) {
          loginRateRecord(rateKey);
          await writeAudit(env, {
            eventType: "login_failed",
            meta: { email, ip: clientIp }
          });
          return json({ error: "Invalid email or password" }, 401);
        }

        loginRateClear(rateKey);

        const token = [...crypto.getRandomValues(new Uint8Array(32))]
          .map(b => b.toString(16).padStart(2, "0"))
          .join("");
        const expiresAt = new Date(Date.now() + sessionSeconds * 1000).toISOString();

        await env.DB.prepare(`
          INSERT INTO sessions (id_hash, user_id, expires_at)
          VALUES (?, ?, ?)
        `).bind(await sha256(token), user.id, expiresAt).run();

        await writeAudit(env, {
          companyId: user.company_id,
          userId: user.id,
          eventType: "login_success",
          meta: { email, ip: clientIp }
        });

        const hasOrigin = Boolean(request.headers.get("Origin"));
        const payload = {
          status: "ok",
          user: {
            email: user.email,
            displayName: user.display_name,
            role: user.role
          }
        };
        if (!hasOrigin) {
          payload.token = token;
          payload.expiresAt = expiresAt;
        }

        return json(payload, 200, {
          "Set-Cookie": sessionCookie(token, sessionSeconds)
        });
      }

      // ---- POST /api/logout ----
      if (url.pathname === "/api/logout" && request.method === "POST") {
        const user = await currentUser(request, env);
        const token = readSessionToken(request);
        if (token) {
          await env.DB.prepare("DELETE FROM sessions WHERE id_hash = ?")
            .bind(await sha256(token)).run();
        }
        if (user) {
          await writeAudit(env, {
            companyId: user.company_id,
            userId: user.id,
            eventType: "logout",
            meta: {}
          });
        }
        return json({ status: "ok" }, 200, {
          "Set-Cookie": sessionCookie("", 0)
        });
      }

      // ---- GET /api/me ----
      if (url.pathname === "/api/me" && request.method === "GET") {
        const user = await currentUser(request, env);
        if (!user) return json({ error: "Authentication required" }, 401);
        return json({
          user: {
            email: user.email,
            displayName: user.display_name,
            role: user.role,
            company: user.company_name
          }
        });
      }

      // ---- Company-scoped operational APIs ----
      const routeMatch = url.pathname.match(/^\/api\/(metrics|plans|subscribers|invoices)$/);
      if (routeMatch) {
        const user = await currentUser(request, env);
        if (!user) return json({ error: "Authentication required" }, 401);
        const resource = routeMatch[1];
        const can = roles => roles.includes(user.role);
        const requireRole = roles => can(roles)
          ? null
          : json({ error: "Insufficient permissions" }, 403);
        const body = request.method === "POST" ? await bodyJsonLimited(request) : null;
        if (request.method === "POST" && !body) return json({ error: "Invalid JSON body" }, 400);

        if (resource === "metrics" && request.method === "GET") {
          const routerId = url.searchParams.get("routerId");
          const result = routerId
            ? await env.DB.prepare(`
                SELECT m.router_id, m.cpu_percent, m.memory_percent,
                       m.temperature_c, m.latency_ms, m.packet_loss_percent,
                       m.rx_bytes_per_second, m.tx_bytes_per_second, m.sampled_at
                FROM router_metrics m
                JOIN routers r ON r.id = m.router_id AND r.company_id = ?
                WHERE m.company_id = ? AND m.router_id = ?
                ORDER BY m.sampled_at DESC LIMIT 100
              `).bind(user.company_id, user.company_id, routerId).all()
            : await env.DB.prepare(`
                SELECT m.router_id, r.name AS router_name, m.cpu_percent,
                       m.memory_percent, m.temperature_c, m.latency_ms,
                       m.packet_loss_percent, m.rx_bytes_per_second,
                       m.tx_bytes_per_second, m.sampled_at
                FROM router_metrics m
                JOIN routers r ON r.id = m.router_id AND r.company_id = ?
                WHERE m.company_id = ?
                ORDER BY m.sampled_at DESC LIMIT 100
              `).bind(user.company_id, user.company_id).all();
          return json({
            metrics: result.results || [],
            source: "stored_samples",
            note: "Stored measurements only; this endpoint does not poll MikroTik directly."
          });
        }

        if (resource === "plans" && request.method === "GET") {
          const result = await env.DB.prepare(`
            SELECT id, name, download_kbps, upload_kbps, price_minor,
                   currency, duration_days, status, created_at
            FROM plans WHERE company_id = ? ORDER BY created_at DESC LIMIT 200
          `).bind(user.company_id).all();
          return json({ plans: result.results || [] });
        }
        if (resource === "plans" && request.method === "POST") {
          const denied = requireRole(["owner", "admin"]);
          if (denied) return denied;
          const name = typeof body.name === "string" ? body.name.trim() : "";
          const download = Number(body.download_kbps);
          const upload = Number(body.upload_kbps);
          const price = body.price_minor === undefined ? 0 : Number(body.price_minor);
          const duration = body.duration_days === undefined ? 30 : Number(body.duration_days);
          const currency = typeof body.currency === "string" ? body.currency.trim().toUpperCase() : "USD";
          if (!name || name.length > 100 || !Number.isSafeInteger(download) || download < 1 ||
              !Number.isSafeInteger(upload) || upload < 1 || !Number.isSafeInteger(price) || price < 0 ||
              !Number.isSafeInteger(duration) || duration < 1 || duration > 3650 ||
              !/^[A-Z]{3}$/.test(currency)) {
            return json({ error: "Invalid plan fields" }, 400);
          }
          const id = crypto.randomUUID();
          await env.DB.prepare(`
            INSERT INTO plans (id, company_id, name, download_kbps, upload_kbps, price_minor, currency, duration_days)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          `).bind(id, user.company_id, name, download, upload, price, currency, duration).run();
          await env.DB.prepare(`
            INSERT INTO audit_events (company_id, actor_user_id, action, resource_type, resource_id)
            VALUES (?, ?, 'create', 'plan', ?)
          `).bind(user.company_id, user.id, id).run();
          return json({ status: "created", id }, 201);
        }

        if (resource === "subscribers" && request.method === "GET") {
          const result = await env.DB.prepare(`
            SELECT s.id, s.router_id, s.plan_id, s.username, s.full_name,
                   s.phone, s.service_type, s.status, s.starts_at, s.expires_at,
                   s.created_at, p.name AS plan_name, r.name AS router_name
            FROM subscribers s
            LEFT JOIN plans p ON p.id = s.plan_id AND p.company_id = s.company_id
            LEFT JOIN routers r ON r.id = s.router_id AND r.company_id = s.company_id
            WHERE s.company_id = ? ORDER BY s.created_at DESC LIMIT 200
          `).bind(user.company_id).all();
          return json({ subscribers: result.results || [] });
        }
        if (resource === "subscribers" && request.method === "POST") {
          const denied = requireRole(["owner", "admin", "technician"]);
          if (denied) return denied;
          const username = typeof body.username === "string" ? body.username.trim() : "";
          const fullName = typeof body.full_name === "string" ? body.full_name.trim() : null;
          const phone = typeof body.phone === "string" ? body.phone.trim() : null;
          const type = body.service_type;
          const status = body.status || "pending";
          const routerId = typeof body.router_id === "string" && body.router_id ? body.router_id : null;
          const planId = typeof body.plan_id === "string" && body.plan_id ? body.plan_id : null;
          if (!username || username.length > 128 || (fullName && fullName.length > 150) ||
              (phone && phone.length > 40) || !["pppoe", "hotspot", "static"].includes(type) ||
              !["active", "suspended", "pending", "expired"].includes(status)) {
            return json({ error: "Invalid subscriber fields" }, 400);
          }
          if (routerId) {
            const r = await env.DB.prepare("SELECT id FROM routers WHERE id = ? AND company_id = ?")
              .bind(routerId, user.company_id).first();
            if (!r) return json({ error: "Router not found in this company" }, 400);
          }
          if (planId) {
            const p = await env.DB.prepare("SELECT id FROM plans WHERE id = ? AND company_id = ? AND status = 'active'")
              .bind(planId, user.company_id).first();
            if (!p) return json({ error: "Active plan not found in this company" }, 400);
          }
          const id = crypto.randomUUID();
          try {
            await env.DB.prepare(`
              INSERT INTO subscribers (id, company_id, router_id, plan_id, username, full_name, phone, service_type, status, starts_at, expires_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            `).bind(id, user.company_id, routerId, planId, username, fullName, phone, type, status,
              typeof body.starts_at === "string" ? body.starts_at : null,
              typeof body.expires_at === "string" ? body.expires_at : null).run();
          } catch (error) {
            if (String(error).includes("UNIQUE")) return json({ error: "Username already exists in this company" }, 409);
            throw error;
          }
          await env.DB.prepare(`
            INSERT INTO audit_events (company_id, actor_user_id, action, resource_type, resource_id)
            VALUES (?, ?, 'create', 'subscriber', ?)
          `).bind(user.company_id, user.id, id).run();
          return json({ status: "created", id }, 201);
        }

        if (resource === "invoices" && request.method === "GET") {
          const result = await env.DB.prepare(`
            SELECT i.id, i.subscriber_id, i.amount_minor, i.currency, i.status,
                   i.due_at, i.paid_at, i.created_at, s.username, s.full_name
            FROM invoices i JOIN subscribers s
              ON s.id = i.subscriber_id AND s.company_id = i.company_id
            WHERE i.company_id = ? ORDER BY i.created_at DESC LIMIT 200
          `).bind(user.company_id).all();
          return json({ invoices: result.results || [] });
        }
        if (resource === "invoices" && request.method === "POST") {
          const denied = requireRole(["owner", "admin", "billing"]);
          if (denied) return denied;
          const subscriberId = typeof body.subscriber_id === "string" ? body.subscriber_id : "";
          const amount = Number(body.amount_minor);
          const currency = typeof body.currency === "string" ? body.currency.trim().toUpperCase() : "USD";
          const dueAt = typeof body.due_at === "string" ? body.due_at : null;
          const subscriber = await env.DB.prepare("SELECT id FROM subscribers WHERE id = ? AND company_id = ?")
            .bind(subscriberId, user.company_id).first();
          if (!subscriber || !Number.isSafeInteger(amount) || amount < 0 || !/^[A-Z]{3}$/.test(currency)) {
            return json({ error: "Invalid invoice fields or subscriber" }, 400);
          }
          const id = crypto.randomUUID();
          await env.DB.prepare(`
            INSERT INTO invoices (id, company_id, subscriber_id, amount_minor, currency, due_at)
            VALUES (?, ?, ?, ?, ?, ?)
          `).bind(id, user.company_id, subscriberId, amount, currency, dueAt).run();
          await env.DB.prepare(`
            INSERT INTO audit_events (company_id, actor_user_id, action, resource_type, resource_id)
            VALUES (?, ?, 'create', 'invoice', ?)
          `).bind(user.company_id, user.id, id).run();
          return json({ status: "created", id }, 201);
        }
        return json({ error: "Method not allowed" }, 405);
      }

      // ---- GET /api/routers ----
      if (url.pathname === "/api/routers" && request.method === "GET") {
        const user = await currentUser(request, env);
        if (!user) return json({ error: "Authentication required" }, 401);
        const result = await env.DB.prepare(`
          SELECT id, name, host_label, model, routeros_version,
                 connection_type, status, last_seen_at, created_at
          FROM routers WHERE company_id = ?
          ORDER BY created_at DESC
        `).bind(user.company_id).all();
        return json({
          routers: result.results || [],
          note: "These are database records, not live router readings."
        });
      }

      if (url.pathname.startsWith("/api/")) {
        if (request.method !== "GET" && request.method !== "POST") {
          return json({ error: "Method not allowed" }, 405);
        }
        return json({ error: "API endpoint not found" }, 404);
      }

      return json({ error: "Not found" }, 404);
    } catch {
      return json({ error: "Internal server error" }, 500);
    }
  }
};
