const { PROF_BACKEND } = require("../config/profBackend");

// POST /api/auth/login
const login = async (req, res) => {
  const { email, username, password } = req.body;
  const loginEmail = email || username; // accept both for backward compatibility
  if (!loginEmail || !password)
    return res.status(400).json({ error: "email and password required" });

  try {
    const upstream = await fetch(`${PROF_BACKEND}/login`, {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body:    JSON.stringify({ email: loginEmail, password }),
    });
    const data = await upstream.json();
    if (!data.token) return res.status(401).json({ error: data.error || "Invalid credentials" });

    return res.json({
      success: true,
      token:   data.token,
      user: {
        id:    data.user_id,
        email: data.email,
        name:  data.name,
        role:  data.role,
      },
    });
  } catch (err) {
    return res.status(502).json({ error: "Auth service unreachable" });
  }
};

module.exports = { login };
