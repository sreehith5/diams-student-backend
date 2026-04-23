const express = require("express");
const router = express.Router();
const { getAnalytics, getActiveSessions, markAttendance, faceVerify, photoStatus, updatePhoto } = require("../controllers/studentController");

router.get("/:studentId/analytics",    getAnalytics);
router.get("/:studentId/sessions",     getActiveSessions);
router.get("/:studentId/photoStatus",  photoStatus);
router.post("/markAttendance",         markAttendance);
router.post("/faceVerify",             faceVerify);
router.post("/:studentId/updatePhoto", updatePhoto);

module.exports = router;
