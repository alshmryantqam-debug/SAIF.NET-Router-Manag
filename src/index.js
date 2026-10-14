
const json = (data, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff"
    }
  });

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname.startsWith("/api/")) {
      if (request.method !== "GET") {
        return json({ error: "Method not allowed" }, 405);
      }

      if (url.pathname === "/api/health") {
        return json({
          service: "SAIF.NET",
          status: "online",
          api: "ready",
          databaseConfigured: Boolean(env.DB)
        });
      }

      if (url.pathname === "/api/routers") {
        return json({
          error: "Authentication and router service are not configured yet"
        }, 503);
      }

      return json({ error: "API endpoint not found" }, 404);
    }

    if (env.ASSETS) {
      return env.ASSETS.fetch(request);
    }

    return new Response("SAIF.NET service unavailable", {
      status: 503
    });
  }
};
