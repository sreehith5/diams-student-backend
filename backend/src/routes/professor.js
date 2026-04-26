const express = require("express");
const router = express.Router();
const { getCourses, getActiveSession, startSession, endSession, getSessionSummary, getCourseAttendance } = require("../controllers/professorController");

router.get("/:professorId/courses",                       getCourses);
router.get("/:professorId/activeSession",                 getActiveSession);
router.post("/session/start",                             startSession);
router.post("/session/end/:sessionId",                    endSession);
router.get("/session/:sessionId/summary",                 getSessionSummary);
router.get("/:professorId/course/:courseCode/attendance", getCourseAttendance);

module.exports = router;
