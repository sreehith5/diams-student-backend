const ABHAY_QR = "https://ble-qr-microservice.onrender.com";

// POST /api/qr/generate
// body: { class_id }
const generateQR = async (req, res) => {
  const { class_id } = req.body;
  if (!class_id) return res.status(400).json({ error: "class_id required" });
  try {
    const data = await fetch(`${ABHAY_QR}/qr/generate`, {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body:    JSON.stringify({ class_id }),
    }).then(r => r.json());
    return res.json(data); // { hash, expires_in }
  } catch (err) {
    return res.status(502).json({ error: "QR service unreachable" });
  }
};

// POST /api/qr/validate
// body: { class_id, hash, timestamp }
const validateQR = async (req, res) => {
  const { class_id, hash, timestamp } = req.body;
  if (!class_id || !hash || !timestamp)
    return res.status(400).json({ error: "class_id, hash and timestamp required" });
  try {
    const data = await fetch(`${ABHAY_QR}/qr/validate`, {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body:    JSON.stringify({ class_id, hash, timestamp }),
    }).then(r => r.json());
    return res.json(data); // { valid: bool }
  } catch (err) {
    return res.status(502).json({ error: "QR service unreachable", valid: false });
  }
};

module.exports = { generateQR, validateQR };
