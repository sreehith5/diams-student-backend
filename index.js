require("dotenv").config();
const express = require("express");
const cors    = require("cors");

const authRoutes      = require("./src/routes/auth");
const studentRoutes   = require("./src/routes/student");
const professorRoutes = require("./src/routes/professor");
const bleRoutes       = require("./src/routes/ble");
const qrRoutes        = require("./src/routes/qr");

const app  = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: "20mb" }));
app.use((req, res, next) => {
  console.log(`→ ${req.method} ${req.url}`);
  const orig = res.json.bind(res);
  res.json = (body) => {
    console.log(`← ${res.statusCode} ${req.url}`, JSON.stringify(body).slice(0, 200));
    return orig(body);
  };
  next();
});

app.use("/api/auth",      authRoutes);
app.use("/api/student",   studentRoutes);
app.use("/api/professor", professorRoutes);
app.use("/api/ble",       bleRoutes);
app.use("/api/qr",        qrRoutes);

app.get("/health", (_, res) => res.json({ status: "ok" }));

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Backend running on http://0.0.0.0:${PORT}`);
});
