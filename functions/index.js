const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.database();
const firestore = admin.firestore();

// Use process.env.GEMINI_API_KEY from Firebase environment or Secret Manager
const getGenerativeModel = () => {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.warn("GEMINI_API_KEY is missing in environment. Using fallback for dev.");
  }
  // Fallback solely for local emulator dev if missing
  const genAI = new GoogleGenerativeAI(apiKey || 'dev-dummy-key');
  return genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
};

// ============================================================================
// FUNCTION 1 — onIncidentConfirmed (Firestore trigger)
// ============================================================================
exports.onIncidentConfirmed = onDocumentCreated(
  "incidents/{incidentId}",
  async (event) => {
    const incidentId = event.params.incidentId;
    const incident = event.data.data();

    // Skip if this was triggered by a test/seed write explicitly flagged
    if (!incident || incident.isTest === true) return;

    try {
      const model = getGenerativeModel();

      const guestLanguage = incident.guestLanguage || "English";
      const unaccounted = incident.totalGuests || 24;
      const venueName = incident.venueName || "CrisisSync Grand Hotel";
      const affectedFloors = incident.affectedFloors || [];

      const context = `
INCIDENT: \${incident.type}, Severity \${incident.severity}/5
Floors: \${affectedFloors.join(', ')}
Action: \${incident.immediateAction || "Evacuate immediately."}
Venue: \${venueName}, Unaccounted guests: \${unaccounted}
Assembly: Main car park, South entrance. Stairwells A (East) and B (West).
`;

      const GUEST_PROMPT = `You are CrisisSync. Generate a calm hotel guest emergency message in \${guestLanguage}. Max 80 words. 4 numbered steps. End with reassurance. No jargon. Context: \${context}`;

      const STAFF_PROMPT = `You are CrisisSync. Generate a hotel staff emergency task list. English only. Start with INCIDENT TYPE AND SEVERITY in caps. 5 numbered tasks. End with headcount instruction. Under 120 words. Context: \${context}`;

      const RESPONDER_PROMPT = `You are CrisisSync. Generate an arriving-unit situation brief. Use exact fields: INCIDENT / LOCATION / CURRENT STATUS / UNACCOUNTED / ACCESS / CONTACT. One sentence per field. Facts only. Context: \${context}`;

      // Run all 3 Gemini calls in PARALLEL
      const [guestResult, staffResult, responderResult] = await Promise.all([
        model.generateContent(GUEST_PROMPT),
        model.generateContent(STAFF_PROMPT),
        model.generateContent(RESPONDER_PROMPT),
      ]);

      const guestMsg = guestResult.response.text();
      const staffMsg = staffResult.response.text();
      const responderMsg = responderResult.response.text();

      const timestamp = Date.now();

      // Write alerts to Realtime DB and update Status
      await Promise.all([
        db.ref(`alerts/guest`).set({ message: guestMsg, language: guestLanguage, timestamp, incidentId }),
        db.ref(`alerts/staff`).set({ message: staffMsg, timestamp, incidentId }),
        db.ref(`alerts/responder`).set({ message: responderMsg, timestamp, incidentId }),
        db.ref(`active_incident`).update({ status: "active", incidentId }),
      ]);

      // Log timeline event
      await firestore
        .collection('incidents')
        .doc(incidentId)
        .collection('timeline')
        .add({
          message: "AI-generated alerts computed via Cloud Functions and dispatched to all 3 roles",
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          timeMillis: Date.now(),
        });

      console.log(`CrisisSync: Incident \${incidentId} — alerts dispatched in parallel.`);
    } catch (e) {
      console.error("Error in onIncidentConfirmed:", e);
    }
  }
);

// ============================================================================
// FUNCTION 2 — generateIncidentReport (HTTP callable)
// ============================================================================
exports.generateIncidentReport = onCall(async (request) => {
  const { incidentId } = request.data;
  if (!incidentId) throw new HttpsError('invalid-argument', 'incidentId is required');

  try {
    // Fetch full incident data from Firestore
    const incidentDoc = await firestore.collection('incidents').doc(incidentId).get();
    const incidentData = incidentDoc.data() || {};

    // Fetch timeline events
    const timelineSnap = await firestore.collection('incidents').doc(incidentId).collection('timeline').orderBy('timeMillis', 'asc').get();
    const timelineEvents = timelineSnap.docs.map(doc => doc.data().message).join('\n- ');

    // Fetch final accountability numbers from Realtime DB
    const musterSnap = await db.ref(`muster/\${incidentId}/rooms`).once('value');
    const musterData = musterSnap.val() || {};
    
    let safe = 0, unaccounted = 0, rescued = 0;
    Object.values(musterData).forEach(guest => {
      if (guest.status === 'safe') safe++;
      else if (guest.status === 'needs_rescue') rescued++;
      else unaccounted++;
    });

    const reportPrompt = `
You are a hotel safety compliance officer. Generate a formal post-incident report.
Use this structure:
1. INCIDENT SUMMARY (2 sentences)
2. TIMELINE OF EVENTS (bullet list from provided data)
3. GUEST ACCOUNTABILITY (safe/unaccounted/needs rescue counts)
4. RESPONSE ASSESSMENT (what worked, what needs improvement)
5. RECOMMENDED FOLLOW-UP ACTIONS (3 bullets)

Data:
Type: \${incidentData.type || 'Unknown'}, Severity: \${incidentData.severity || 'N/A'}
Timeline:
- \${timelineEvents || 'None recorded'}
Accountability: Safe: \${safe}, Unaccounted: \${unaccounted}, Needs Rescue: \${rescued}
`;

    const model = getGenerativeModel();
    const result = await model.generateContent(reportPrompt);
    
    return { report: result.response.text() };
  } catch (e) {
    console.error("Error generating report:", e);
    throw new HttpsError('internal', 'Failed to generate report.');
  }
});

// ============================================================================
// FUNCTION 3 — seedDemoData (HTTP callable, dev only)
// ============================================================================
exports.seedDemoData = onCall(async (request) => {
  try {
    const incidentId = Date.now().toString();

    // 1. Create a test incident (isTest=false, to trigger the Cloud Function intentionally)
    await firestore.collection('incidents').doc(incidentId).set({
      type: "fire",
      severity: 4,
      affectedFloors: [3, 4],
      detectedAt: Date.now(),
      status: "active",
      confidence: 0.95,
      immediateAction: "Evacuate floors 3 and 4 immediately.",
      isTest: false, // Ensures it hits onIncidentConfirmed!
    });

    // 2. Seed 20 guest records to /muster
    const guests = [
      {"roomNumber":"301","guestName":"Sharma, R.","floor":3,"status":"unaccounted","notes":""},
      {"roomNumber":"302","guestName":"Patel, A.","floor":3,"status":"unaccounted","notes":""},
      {"roomNumber":"303","guestName":"Kumar, S.","floor":3,"status":"unaccounted","notes":""},
      {"roomNumber":"401","guestName":"Johnson, M.","floor":4,"status":"unaccounted","notes":"elderly"},
      {"roomNumber":"402","guestName":"Chen, W.","floor":4,"status":"unaccounted","notes":""},
      {"roomNumber":"403","guestName":"Al-Hassan, F.","floor":4,"status":"unaccounted","notes":""},
      {"roomNumber":"404","guestName":"Reddy, K.","floor":4,"status":"unaccounted","notes":"mobility aid"},
      {"roomNumber":"501","guestName":"Ivanova, N.","floor":5,"status":"unaccounted","notes":""},
      {"roomNumber":"502","guestName":"Singh, P.","floor":5,"status":"unaccounted","notes":"infant"},
      {"roomNumber":"304","guestName":"Gupta, D.","floor":3,"status":"unaccounted","notes":""},
      {"roomNumber":"305","guestName":"Silva, M.","floor":3,"status":"unaccounted","notes":"wheelchair"},
      {"roomNumber":"306","guestName":"Takahashi, K.","floor":3,"status":"unaccounted","notes":""},
      {"roomNumber":"307","guestName":"Brown, T.","floor":3,"status":"unaccounted","notes":""},
      {"roomNumber":"308","guestName":"Nguyen, H.","floor":3,"status":"unaccounted","notes":""},
      {"roomNumber":"405","guestName":"Kim, Y.","floor":4,"status":"unaccounted","notes":""},
      {"roomNumber":"406","guestName":"Gomez, L.","floor":4,"status":"unaccounted","notes":"asthma"},
      {"roomNumber":"407","guestName":"Ali, O.","floor":4,"status":"unaccounted","notes":""},
      {"roomNumber":"408","guestName":"Rossi, G.","floor":4,"status":"unaccounted","notes":""},
      {"roomNumber":"503","guestName":"Weber, J.","floor":5,"status":"unaccounted","notes":""},
      {"roomNumber":"504","guestName":"Fernandez, C.","floor":5,"status":"unaccounted","notes":"infant"},
    ];

    const updates = {};
    for (const g of guests) {
      updates[`muster/\${incidentId}/rooms/\${g.roomNumber}`] = g;
    }
    await db.ref().update(updates);

    // 3. Set Active Incident
    await db.ref('active_incident').set({ status: 'active', incidentId });

    return { success: true, incidentId };
  } catch (e) {
    console.error("Error seeding demo data:", e);
    throw new HttpsError('internal', 'Failed to seed demo data.');
  }
});
