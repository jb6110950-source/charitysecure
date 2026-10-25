const jsonHeaders = { "Content-Type": "application/json; charset=utf-8" };

function response(statusCode, body) {
  return { statusCode, headers: jsonHeaders, body: JSON.stringify(body) };
}

function getConfiguration() {
  const url = process.env.SUPABASE_URL?.replace(/\/+$/, "");
  const anonKey = process.env.SUPABASE_ANON_KEY;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !anonKey || !serviceRoleKey) {
    throw new Error("Supabase environment variables are not configured.");
  }
  return { url, anonKey, serviceRoleKey };
}

async function getAdminUser(event, config) {
  const authorization = event.headers.authorization || event.headers.Authorization || "";
  const token = authorization.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return null;

  const userResponse = await fetch(`${config.url}/auth/v1/user`, {
    headers: { apikey: config.anonKey, Authorization: `Bearer ${token}` }
  });
  if (!userResponse.ok) return null;
  const user = await userResponse.json();

  const profileResponse = await fetch(
    `${config.url}/rest/v1/profiles?id=eq.${encodeURIComponent(user.id)}&select=role`,
    { headers: { apikey: config.serviceRoleKey, Authorization: `Bearer ${config.serviceRoleKey}` } }
  );
  if (!profileResponse.ok) throw new Error("The administrator role could not be verified.");
  const profiles = await profileResponse.json();
  return profiles[0]?.role === "admin" ? user : null;
}

export async function handler(event) {
  if (event.httpMethod !== "GET" && event.httpMethod !== "POST") {
    return response(405, { error: "Method not allowed." });
  }

  let config;
  try {
    config = getConfiguration();
    const admin = await getAdminUser(event, config);
    if (!admin) return response(403, { error: "Administrator sign-in is required." });

    if (event.httpMethod === "GET") {
      const result = await fetch(`${config.url}/rest/v1/profiles?select=id,email,role,created_at&order=created_at.asc`, {
        headers: { apikey: config.serviceRoleKey, Authorization: `Bearer ${config.serviceRoleKey}` }
      });
      if (!result.ok) return response(502, { error: "The user list could not be loaded." });
      return response(200, { users: await result.json() });
    }

    let body;
    try {
      body = JSON.parse(event.body || "{}");
    } catch {
      return response(400, { error: "The request body is not valid JSON." });
    }
    const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
      return response(400, { error: "Enter a valid email address." });
    }

    const redirectTo = `${process.env.URL || config.url}/contacts.html`;
    const invite = await fetch(`${config.url}/auth/v1/invite?redirect_to=${encodeURIComponent(redirectTo)}`, {
      method: "POST",
      headers: {
        apikey: config.serviceRoleKey,
        Authorization: `Bearer ${config.serviceRoleKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ email })
    });
    if (!invite.ok) {
      const details = await invite.json().catch(() => ({}));
      return response(invite.status === 422 ? 409 : 502, { error: details.msg || details.message || "The invitation could not be sent." });
    }

    return response(200, { message: `An invitation was sent to ${email}.` });
  } catch (error) {
    console.error("Admin user request failed.", error);
    return response(500, { error: error.message || "The user request could not be completed." });
  }
}
