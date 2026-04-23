const express = require("express");
const router = express.Router();
const { getMajor, validateBLE } = require("../controllers/bleController");

router.get("/major/:classroom", getMajor);
router.post("/validate",        validateBLE);

module.exports = router;
