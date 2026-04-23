const express = require("express");
const router = express.Router();
const { generateQR, validateQR } = require("../controllers/qrController");

router.post("/generate", generateQR);
router.post("/validate", validateQR);

module.exports = router;
