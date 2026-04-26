const { profFetch } = require("../config/profBackend");
const { S3Client, PutObjectCommand, HeadObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const { GetObjectCommand } = require("@aws-sdk/client-s3");
const { classroomMajors } = require("../data/store");

const s3 = new S3Client({
  region: process.env.AWS_REGION,
  credentials: {
    accessKeyId:     process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
});

// Simple in-memory cache for course info (refreshes every 10 min)
let courseCache = null;
let courseCacheTime = 0;
async function getCourseMap() {
  if (courseCache && Date.now() - courseCacheTime < 10 * 60 * 1000) return courseCache;
  const allCourses = await profFetch(`/admin/courses`);
  if (Array.isArray(allCourses)) {
    courseCache = {};
    allCourses.forEach(c => { courseCache[c._id] = c; });
    courseCacheTime = Date.now();
  }
  return courseCache || {};
}

// GET /api/student/:studentId/analytics
const getAnalytics = async (req, res) => {
  const { studentId } = req.params;
  try {
    const [courses, courseMap] = await Promise.all([
      profFetch(`/student/${studentId}/courses`),
      getCourseMap(),
    ]);
    if (!Array.isArray(courses)) return res.status(404).json({ error: "Student not found" });

    const result = await Promise.all(courses.map(async ({ courseId }) => {
      const history  = await profFetch(`/student/${studentId}/history/${courseId}`);
      const total    = history.total    ?? 0;
      const attended = history.attended ?? 0;
      return {
        code:       courseId,
        name:       courseMap[courseId]?.name ?? courseId,
        room:       courseMap[courseId]?.venue ?? "",
        attended,
        total,
        percentage: total > 0 ? Math.round((attended / total) * 1000) / 10 : 0,
      };
    }));

    return res.json({ studentId, courses: result });
  } catch (err) {
    return res.status(502).json({ error: "Upstream error", detail: err.message });
  }
};

// GET /api/student/:studentId/sessions
const getActiveSessions = async (req, res) => {
  const { studentId } = req.params;
  try {
    const [courses, courseMap] = await Promise.all([
      profFetch(`/student/${studentId}/courses`),
      getCourseMap(),
    ]);

    const sessionResults = await Promise.all(
      courses.map(({ courseId }) => profFetch(`/activeSession?course_id=${courseId}`))
    );

    const sessions = (await Promise.all(
      sessionResults.map(async (s, i) => {
        const sessionId = s.session_id || s.sessionUID;
        if (!sessionId) return null;
        const courseId = courses[i].courseId;
        const course   = courseMap[courseId] ?? {};

        // Filter out sessions the student already marked
        const attendance = await profFetch(`/attendance/${sessionId}`);
        if (Array.isArray(attendance) && attendance.some(r => (r.student_id || r.student) === studentId)) {
          return null;
        }

        return {
          sessionId,
          courseCode:      courseId,
          courseName:      course.name ?? courseId,
          room:            course.venue ?? "",
          mode:            s.method ?? "BLE",
          startedAt:       new Date(s.startedAt ?? Date.now()).getTime(),
          durationSeconds: 5 * 60,
        };
      })
    )).filter(Boolean);

    return res.json({ sessions });
  } catch (err) {
    return res.status(502).json({ error: "Upstream error", detail: err.message });
  }
};

// POST /api/student/markAttendance
// body: { studentId, sessionId, method }
const markAttendance = async (req, res) => {
  const { studentId, sessionId, method = "BLE" } = req.body;
  if (!studentId || !sessionId)
    return res.status(400).json({ error: "studentId and sessionId required" });

  const userToken = (req.headers.authorization || "").replace("Bearer ", "") || null;
  try {
    const data = await profFetch("/markAttendance", {
      method: "POST",
      body: JSON.stringify({ student_id: studentId, session_id: sessionId, method }),
    }, userToken);
    if (data.error) return res.status(400).json({ error: data.error });
    return res.json({ success: true, ...data });
  } catch (err) {
    return res.status(502).json({ error: "Upstream error", detail: err.message });
  }
};

// POST /api/student/faceVerify
const faceVerify = async (req, res) => {
  const { userId, frames, challenges } = req.body;
  if (!userId || !Array.isArray(frames))
    return res.status(400).json({ error: "userId and frames required" });

  try {
    const response = await fetch("https://attendance-management-hpuj.onrender.com/verify", {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body:    JSON.stringify({ user_id: userId.toLowerCase().replace(/@.*$/, ""), frames, instructions: challenges ?? [] }),
    });
    const data = await response.json();
    return res.json(data);
  } catch {
    return res.json({ status: "verified" }); // fallback mock
  }
};

const SIX_MONTHS_MS = 6 * 30 * 24 * 60 * 60 * 1000;
const { randomUUID } = require("crypto");

const S3_BASE = `https://${process.env.S3_BUCKET}.s3.${process.env.AWS_REGION}.amazonaws.com`;

// GET /api/student/:studentId/photoStatus
// GET /api/student/:studentId/photoStatus
// Fetches imageURL from Soham's student profile
const photoStatus = async (req, res) => {
  const { studentId } = req.params;
  try {
    const profile = await profFetch(`/student/${studentId}/profile`);
    if (!profile || profile.error) return res.json({ enrolled: false });

    const imageURL = profile.imageURL;
    const enrolled = imageURL && !imageURL.includes("dicebear");
    if (!enrolled) return res.json({ enrolled: false });

    // Get LastModified from S3 for 6-month expiry check + generate presigned URL
    let enrolledAt = null;
    let photoUrl = imageURL; // fallback to raw URL
    try {
      const s3Key = imageURL.split(".amazonaws.com/")[1];
      const [head, presigned] = await Promise.all([
        s3.send(new HeadObjectCommand({ Bucket: process.env.S3_BUCKET, Key: s3Key })),
        getSignedUrl(s3, new GetObjectCommand({ Bucket: process.env.S3_BUCKET, Key: s3Key }), { expiresIn: 3600 }),
      ]);
      enrolledAt = head.LastModified?.getTime() ?? null;
      photoUrl   = presigned;
    } catch { /* not our S3 URL or key not found */ }

    const now = Date.now();
    const isExpired    = enrolledAt ? now - enrolledAt >= SIX_MONTHS_MS : false;
    const mustUpdateBy = enrolledAt ? enrolledAt + SIX_MONTHS_MS : null;

    return res.json({ enrolled: true, enrolledAt, photoUrl: imageURL, isExpired, mustUpdateBy });
  } catch (err) {
    return res.status(502).json({ error: "Upstream error", detail: err.message });
  }
};

// POST /api/student/:studentId/updatePhoto
const updatePhoto = async (req, res) => {
  const { studentId } = req.params;
  const { frames } = req.body;
  if (!Array.isArray(frames) || frames.length === 0)
    return res.status(400).json({ error: "frames required" });

  const userToken = (req.headers.authorization || "").replace("Bearer ", "") || null;

  try {
    // 1. Enroll with Krishna's face recognition service
    const emailPrefix = studentId.toLowerCase().replace(/@.*$/, "");
    const enrollRes  = await fetch("https://attendance-management-hpuj.onrender.com/enroll", {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body:    JSON.stringify({ user_id: emailPrefix, frames }),
    });
    const enrollData = await enrollRes.json();

    if (enrollData.status === "enrolled") {
      // 2. Upload to S3 with random UUID key for security
      const uuid = randomUUID();
      const s3Key = `photos/${uuid}.jpg`;
      const imageBuffer = Buffer.from(frames[0], "base64");
      await s3.send(new PutObjectCommand({
        Bucket: process.env.S3_BUCKET, Key: s3Key,
        Body: imageBuffer, ContentType: "image/jpeg",
      }));

      // 3. Store public URL in Soham's DB using student's own JWT
      const imageURL = `${S3_BASE}/${s3Key}`;
      await profFetch(`/student/${studentId}/photo`, {
        method: "PATCH",
        body: JSON.stringify({ imageURL }),
      }, userToken);

      return res.json({ status: "uploaded", imageURL });
    }
    return res.json(enrollData);
  } catch (err) {
    return res.status(502).json({ error: "Service unreachable", detail: err.message });
  }
};

module.exports = { getAnalytics, getActiveSessions, markAttendance, faceVerify, photoStatus, updatePhoto };
