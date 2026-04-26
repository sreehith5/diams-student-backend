const PROF_BACKEND = "https://attendance-management-gazr.onrender.com";

// Service account — used by our backend to call his backend
const SERVICE_EMAIL    = "admin@iith.ac.in";
const SERVICE_PASSWORD = "adminpass";

let cachedToken = null;
let tokenExpiry  = 0;

async function getAuthToken() {
  if (cachedToken && Date.now() < tokenExpiry) return cachedToken;

  const res  = await fetch(`${PROF_BACKEND}/login`, {
    method:  "POST",
    headers: { "Content-Type": "application/json" },
    body:    JSON.stringify({ email: SERVICE_EMAIL, password: SERVICE_PASSWORD }),
  });
  const data = await res.json();
  if (!data.token) throw new Error("Service account login failed");

  cachedToken = data.token;
  tokenExpiry  = Date.now() + 11 * 60 * 60 * 1000; // refresh 1h before 12h expiry
  return cachedToken;
}

async function profFetch(path, options = {}, userToken = null) {
  const token = userToken ?? await getAuthToken();
  const res = await fetch(`${PROF_BACKEND}${path}`, {
    ...options,
    headers: { "Authorization": `Bearer ${token}`, "Content-Type": "application/json", ...(options.headers || {}) },
  });
  return res.json();
}

module.exports = { PROF_BACKEND, getAuthToken, profFetch };
