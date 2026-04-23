const { classroomMajors } = require("../data/store");
const ABHAY_BLE = "https://ble-qr-microservice.onrender.com";

// GET /api/ble/major/:classroom
const getMajor = (req, res) => {
  const major = classroomMajors[req.params.classroom];
  if (!major) return res.status(404).json({ error: "No beacon registered for this classroom" });
  return res.json({ classroom: req.params.classroom, major });
};

function median(values) {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 !== 0 ? sorted[mid] : Math.round((sorted[mid - 1] + sorted[mid]) / 2);
}

// POST /api/ble/validate
// body: { class_id, beacons: [{ major, minor, rssi }] }
// iOS sends ALL readings collected over 3s scan.
// We group by major+minor, compute median RSSI per unique beacon, send to Abhay.
const validateBLE = async (req, res) => {
  const { class_id, beacons } = req.body;
  if (!class_id || !Array.isArray(beacons) || beacons.length === 0)
    return res.status(400).json({ error: "class_id and beacons array required" });

  // Group all readings by major+minor
  const groups = {};
  for (const b of beacons) {
    const key = `${b.major}-${b.minor}`;
    if (!groups[key]) groups[key] = { major: b.major, minor: b.minor, rssis: [] };
    groups[key].rssis.push(b.rssi);
  }

  // Compute median RSSI per unique beacon
  const dedupedBeacons = Object.values(groups).map(g => ({
    major: g.major,
    minor: g.minor,
    rssi:  median(g.rssis),
  }));

  try {
    const response = await fetch(`${ABHAY_BLE}/ble/validate`, {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body:    JSON.stringify({ class_id, beacons: dedupedBeacons }),
    });
    return res.json(await response.json());
  } catch (err) {
    return res.status(502).json({ error: "Abhay's BLE service unreachable", valid: false });
  }
};

module.exports = { getMajor, validateBLE };
