const { profFetch } = require("../config/profBackend");

// GET /api/professor/:professorId/courses
const getCourses = async (req, res) => {
  try {
    const courses = await profFetch(`/courses/${req.params.professorId}`);
    return res.json({ courses: Array.isArray(courses) ? courses : [] });
  } catch (err) {
    return res.status(502).json({ error: "Upstream error", detail: err.message });
  }
};

// GET /api/professor/:professorId/activeSession
const getActiveSession = async (req, res) => {
  const { professorId } = req.params;
  try {
    const courses = await profFetch(`/courses/${professorId}`);
    if (!Array.isArray(courses) || courses.length === 0) return res.json({ session: null });

    for (const course of courses) {
      const s = await profFetch(`/activeSession?course_id=${course._id}`);
      // Soham returns {} when no session, or {session_id, method, startedAt, activeSessions} when active
      const sessionId = s.session_id || s.sessionUID;
      if (!sessionId) continue;
      return res.json({
        session: {
          id:              sessionId,
          courseCode:      course._id,
          mode:            s.method ?? "BLE",
          professorId,
          startedAt:       new Date(s.startedAt ?? Date.now()).getTime(),
          durationSeconds: 5 * 60,
        }
      });
    }
    return res.json({ session: null });
  } catch (err) {
    return res.status(502).json({ error: "Upstream error", detail: err.message });
  }
};

// POST /api/professor/session/start
const startSession = async (req, res) => {
  const { courseCode, mode } = req.body;
  if (!courseCode || !mode) return res.status(400).json({ error: "courseCode and mode required" });
  const userToken = (req.headers.authorization || "").replace("Bearer ", "") || null;
  try {
    const data = await profFetch("/startSession", {
      method: "POST",
      body: JSON.stringify({ course_id: courseCode, mode: mode.toUpperCase() }),
    }, userToken);
    if (data.error) return res.status(400).json({ error: data.error });

    return res.json({
      success: true,
      session: {
        id:              data.session_id,
        startedAt:       Date.now(),
        durationSeconds: 5 * 60,
        courseCode,
        mode,
      }
    });
  } catch (err) {
    return res.status(502).json({ error: "Upstream error", detail: err.message });
  }
};

// POST /api/professor/session/end/:sessionId
const endSession = async (req, res) => {
  const userToken = (req.headers.authorization || "").replace("Bearer ", "") || null;
  try {
    const data = await profFetch(`/endSession/${req.params.sessionId}`, { method: "POST" }, userToken);
    return res.json(data);
  } catch (err) {
    return res.status(502).json({ error: "Upstream error", detail: err.message });
  }
};

// GET /api/professor/session/:sessionId/summary
const getSessionSummary = async (req, res) => {
  try {
    const data = await profFetch(`/attendance/${req.params.sessionId}`);
    return res.json(data);
  } catch (err) {
    return res.status(502).json({ error: "Upstream error", detail: err.message });
  }
};

// GET /api/professor/:professorId/course/:courseCode/attendance
const getCourseAttendance = async (req, res) => {
  try {
    const data = await profFetch(`/analytics/course/${req.params.courseCode}/students`);
    // Map Soham's field names to what our iOS app expects
    const students = (data.studentStats ?? []).map(s => ({
      studentId:  s.student_id,
      name:       s.name,
      attended:   s.attended,
      total:      s.totalLectures,
      percentage: s.attendancePct,
    }));
    return res.json({ courseCode: req.params.courseCode, students });
  } catch (err) {
    return res.status(502).json({ error: "Upstream error", detail: err.message });
  }
};

// POST /api/professor/session/:sessionId/manualAttendance
// body: { studentIds: [] }
const manualAttendance = async (req, res) => {
  const { sessionId } = req.params;
  const { studentIds } = req.body;
  if (!Array.isArray(studentIds) || studentIds.length === 0)
    return res.status(400).json({ error: "studentIds array required" });
  const userToken = (req.headers.authorization || "").replace("Bearer ", "") || null;
  try {
    const data = await profFetch("/manualAttendance/bulk", {
      method: "POST",
      body: JSON.stringify({ session_id: sessionId, student_ids: studentIds }),
    }, userToken);
    return res.json(data);
  } catch (err) {
    return res.status(502).json({ error: "Upstream error", detail: err.message });
  }
};

// POST /api/professor/:courseId/schedule
const addSchedule = async (req, res) => {
  const userToken = (req.headers.authorization || "").replace("Bearer ", "") || null;
  try {
    const data = await profFetch(`/courses/${req.params.courseId}/schedule`, {
      method: "POST",
      body: JSON.stringify(req.body),
    }, userToken);
    return res.json(data);
  } catch (err) {
    return res.status(502).json({ error: "Upstream error", detail: err.message });
  }
};

// PATCH /api/professor/:courseId/schedule/:scheduleId
const updateSchedule = async (req, res) => {
  const userToken = (req.headers.authorization || "").replace("Bearer ", "") || null;
  try {
    const data = await profFetch(`/courses/${req.params.courseId}/schedule/${req.params.scheduleId}`, {
      method: "PATCH",
      body: JSON.stringify(req.body),
    }, userToken);
    return res.json(data);
  } catch (err) {
    return res.status(502).json({ error: "Upstream error", detail: err.message });
  }
};

// DELETE /api/professor/:courseId/schedule/:scheduleId
const deleteSchedule = async (req, res) => {
  const userToken = (req.headers.authorization || "").replace("Bearer ", "") || null;
  try {
    const data = await profFetch(`/courses/${req.params.courseId}/schedule/${req.params.scheduleId}`, {
      method: "DELETE",
    }, userToken);
    return res.json(data);
  } catch (err) {
    return res.status(502).json({ error: "Upstream error", detail: err.message });
  }
};

module.exports = { getCourses, getActiveSession, startSession, endSession, getSessionSummary, getCourseAttendance, manualAttendance, addSchedule, updateSchedule, deleteSchedule };
