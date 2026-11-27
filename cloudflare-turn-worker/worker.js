/**
 * Hamza Jani TURN credential endpoint.
 * Worker variables/secrets: TURN_KEY_ID, TURN_API_TOKEN, FIREBASE_WEB_API_KEY.
 * Keep TURN_API_TOKEN secret; it must never be shipped in the APK.
 */
export default {
  async fetch(request, env) {
    const cors = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Authorization, Content-Type",
      "Cache-Control": "no-store",
    };
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
    if (request.method !== "POST") return Response.json({ error: "Method not allowed" }, { status: 405, headers: cors });
    if (!env.TURN_KEY_ID || !env.TURN_API_TOKEN || !env.FIREBASE_WEB_API_KEY) {
      return Response.json({ error: "TURN service is not configured" }, { status: 503, headers: cors });
    }
    const auth = request.headers.get("Authorization") || "";
    if (!auth.startsWith("Bearer ")) return Response.json({ error: "Authentication required" }, { status: 401, headers: cors });
    try {
      const idToken = auth.slice(7);
      const verifyResponse = await fetch(
        `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(env.FIREBASE_WEB_API_KEY)}`,
        { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ idToken }) },
      );
      if (!verifyResponse.ok) return Response.json({ error: "Invalid or expired sign-in" }, { status: 401, headers: cors });
      const identity = await verifyResponse.json();
      if (!identity.users || identity.users.length !== 1 || identity.users[0].disabled) {
        return Response.json({ error: "Account is not allowed" }, { status: 403, headers: cors });
      }
      const turnResponse = await fetch(
        `https://rtc.live.cloudflare.com/v1/turn/keys/${encodeURIComponent(env.TURN_KEY_ID)}/credentials/generate-ice-servers`,
        {
          method: "POST",
          headers: { "Authorization": `Bearer ${env.TURN_API_TOKEN}`, "Content-Type": "application/json" },
          body: JSON.stringify({ ttl: 3600, customIdentifier: identity.users[0].localId }),
        },
      );
      const payload = await turnResponse.json();
      if (!turnResponse.ok || !Array.isArray(payload.iceServers)) {
        return Response.json({ error: "Could not issue TURN credentials" }, { status: 502, headers: cors });
      }
      return Response.json({ iceServers: payload.iceServers }, { status: 200, headers: cors });
    } catch (_) {
      return Response.json({ error: "TURN credential service failed" }, { status: 500, headers: cors });
    }
  },
};
