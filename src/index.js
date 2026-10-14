
const json = (data, status = 200, extraHeaders = {}) =>
  new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
      ...extraHeaders
    }
  });

const cookieName = "__Host-saif_session";
const sessionDays = 7;

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
    {
      name: "PBKDF2",
      hash: "SHA-256",
      salt,
      iterations: 310000
    },
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

    const salt = new Uint8Array(
      saltHex.match(/.{2}/g).map(x => parseInt(x, 16))
    );
    const actual = await hashPassword(password, salt);
    const actualHash = actual.split("$")[3];

    if (actualHash.length !== expected.length) return false;
    let diff = 0;
    for (let i = 0; i < expected.length; i++) {
      diff |= actualHash.charCodeAt(i) ^ expected.charCodeAt(i);
    }
    return diff === 0;
  } catch {
    return false;
  }
}

async function bodyJson(request) {
  try {
    return await request.json();
  } catch {
    return null;
  }
}

function validPassword(password) {
  return typeof password === "string" &&
    password.length >= 12 &&
    password.length <= 128;
}

async function currentUser(request, env) {
  const token = readCookie(request, cookieName);
  if (!token || !env.DB) return null;

  const idHash = await sha256(token);
  const row = await env.DB.prepare(`
    SELECT u.id, u.company_id, u.email, u.display_name, u.role,
           u.status, c.name AS company_name, s.expires_at
    FROM sessions s
    JOIN users u ON u.id = s.user_id
    JOIN companies c ON c.id = u.company_id
    WHERE s.id_hash = ?
  `).bind(idHash).first();

  if (!row || row.status !== "active") return null;

  const expires = Date.parse(row.expires_at);
  if (!Number.isFinite(expires) || expires <= Date.now()) {
    await env.DB.prepare(
      "DELETE FROM sessions WHERE id_hash = ?"
    ).bind(idHash).run();
    return null;
  }

  return row;
}

function sameOrigin(request) {
  const origin = request.headers.get("Origin");
  if (!origin) return false;

  try {
    return new URL(origin).origin === new URL(request.url).origin;
  } catch {
    return false;
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    try {
      if (!url.pathname.startsWith("/api/")) {
        if (env.ASSETS) return env.ASSETS.fetch(request);
        return new Response("SAIF.NET service unavailable", {
          status: 503
        });
      }

      if (!env.DB) {
        return json({ error: "Database unavailable" }, 503);
      }

      if (url.pathname === "/api/health" && request.method === "GET") {
        return json({
          service: "SAIF.NET",
          status: "online",
          api: "ready",
          databaseConfigured: true
        });
      }

      if (request.method === "POST" && !sameOrigin(request)) {
        return json({ error: "Invalid request origin" }, 403);
      }

      if (url.pathname === "/api/setup" && request.method === "POST") {
        if (!env.SETUP_SECRET) {
          return json({ error: "Initial setup is not configured" }, 503);
        }

        const body = await bodyJson(request);
        if (!body || typeof body.secret !== "string") {
          return json({ error: "Invalid request" }, 400);
        }

        if (body.secret !== env.SETUP_SECRET) {
          return json({ error: "Forbidden" }, 403);
        }

        const existing = await env.DB.prepare(
          "SELECT COUNT(*) AS total FROM users"
        ).first();

        if (Number(existing?.total || 0) !== 0) {
          return json({ error: "Initial setup already completed" }, 409);
        }

        const email = typeof body.email === "string"
          ? body.email.trim().toLowerCase()
          : "";
        const password = body.password;
        const displayName = typeof body.displayName === "string"
          ? body.displayName.trim()
          : "";
        const companyName = typeof body.companyName === "string"
          ? body.companyName.trim()
          : "";

        if (
          !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
          email.length > 254 ||
          !validPassword(password) ||
          !displayName ||
          displayName.length > 100 ||
          !companyName ||
          companyName.length > 120
        ) {
          return json({
            error: "Check email, password (12-128 characters), name and company"
          }, 400);
        }

        const companyId = crypto.randomUUID();
        const userId = crypto.randomUUID();
        const slug = `saif-${crypto.randomUUID()}`;

        const passwordHash = await hashPassword(password);

        await env.DB.prepare(
          "INSERT INTO companies (id, name, slug) VALUES (?, ?, ?)"
        ).bind(companyId, companyName, slug).run();

        await env.DB.prepare(`
          INSERT INTO users
            (id, company_id, email, display_name, password_hash, role)
          VALUES (?, ?, ?, ?, ?, 'owner')
        `).bind(
          userId, companyId, email, displayName, passwordHash
        ).run();

        return json({
          status: "created",
          message: "Owner account created. You can now sign in."
        }, 201);
      }

      if (url.pathname === "/api/login" && request.method === "POST") {
        const body = await bodyJson(request);
        if (!body || typeof body.email !== "string" ||
            typeof body.password !== "string") {
          return json({ error: "Invalid email or password" }, 400);
        }

        const email = body.email.trim().toLowerCase();
        if (email.length > 254 || body.password.length > 128) {
          return json({ error: "Invalid email or password" }, 400);
        }

        const user = await env.DB.prepare(`
          SELECT id, company_id, email, display_name, password_hash,
                 role, status
          FROM users WHERE email = ? COLLATE NOCASE
        `).bind(email).first();

        if (
          !user ||
          user.status !== "active" ||
          !(await verifyPassword(body.password, user.password_hash))
        ) {
          return json({ error: "Invalid email or password" }, 401);
        }

        const token = [...crypto.getRandomValues(new Uint8Array(32))]
          .map(b => b.toString(16).padStart(2, "0"))
          .join("");

        const expiresAt = new Date(
          Date.now() + sessionDays * 86400000
        ).toISOString();

        await env.DB.prepare(`
          INSERT INTO sessions (id_hash, user_id, expires_at)
          VALUES (?, ?, ?)
        `).bind(await sha256(token), user.id, expiresAt).run();

        return json({
          status: "ok",
          user: {
            email: user.email,
            displayName: user.display_name,
            role: user.role
          }
        }, 200, {
          "Set-Cookie": sessionCookie(token, sessionDays * 86400)
        });
      }

      if (url.pathname === "/api/logout" && request.method === "POST") {
        const token = readCookie(request, cookieName);
        if (token) {
          await env.DB.prepare(
            "DELETE FROM sessions WHERE id_hash = ?"
          ).bind(await sha256(token)).run();
        }

        return json({ status: "ok" }, 200, {
          "Set-Cookie": sessionCookie("", 0)
        });
      }

      if (url.pathname === "/api/me" && request.method === "GET") {
        const user = await currentUser(request, env);
        if (!user) {
          return json({ error: "Authentication required" }, 401);
        }

        return json({
          user: {
            email: user.email,
            displayName: user.display_name,
            role: user.role,
            company: user.company_name
          }
        });
      }

      if (url.pathname === "/api/routers" && request.method === "GET") {
        const user = await currentUser(request, env);
        if (!user) {
          return json({ error: "Authentication required" }, 401);
        }

        const result = await env.DB.prepare(`
          SELECT id, name, host_label, model, routeros_version,
                 connection_type, status, last_seen_at, created_at
          FROM routers
          WHERE company_id = ?
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
