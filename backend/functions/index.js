const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const ngeohash = require("ngeohash");

initializeApp();

// A geohash of precision 7 covers an area of ~153m x 153m.
const GEOHASH_PRECISION = 7;
// We require at least 3 unique user reports to verify a pothole.
const VERIFICATION_THRESHOLD = 3;

exports.aggregateDetection = onDocumentCreated(
  {
    database: "roadse",
    document: "detections/{detectionId}",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }
    const data = snapshot.data();

    // 1. Calculate Geohash for the new detection
    const latitude = data.latitude || data.lat;
    const longitude = data.longitude || data.lng;
    
    if (!latitude || !longitude) {
      console.error("Missing latitude/longitude in detection data");
      return;
    }

    const geohash = ngeohash.encode(latitude, longitude, GEOHASH_PRECISION);

    // 2. Query for other detections in the same geohash cluster
    const db = getFirestore();
    const detectionsRef = db.collection("detections");
    const querySnapshot = await detectionsRef.where("geohash", "==", geohash).get();

    if (querySnapshot.empty) {
      // This should not happen, as the current event is in the cluster
      console.log(`No detections found for geohash: ${geohash}`);
      // As a fallback, add geohash to the current document for future queries
      await snapshot.ref.update({ geohash: geohash });
      return;
    }

    const detections = [];
    querySnapshot.forEach((doc) => {
      detections.push(doc.data());
    });

    // 3. Check for unique users
    const uniqueUserIds = new Set(detections
      .map((d) => d.userId)
      .filter(id => id && id !== 'anonymous'));

    console.log(`Geohash ${geohash} has ${uniqueUserIds.size} unique user reports.`);

    // 4. If threshold is met, create or update a Verified Pothole
    if (uniqueUserIds.size >= VERIFICATION_THRESHOLD) {
      console.log(`Verification threshold met for geohash ${geohash}. Aggregating...`);

      const totalLatitude = detections.reduce((sum, d) => sum + (d.latitude || d.lat || 0), 0);
      const totalLongitude = detections.reduce((sum, d) => sum + (d.longitude || d.lng || 0), 0);
      const totalSeverity = detections.reduce((sum, d) => {
        const sev = d.severity;
        const sevValue = typeof sev === 'string' ? 
          (sev.toUpperCase() === 'HIGH' ? 3 : sev.toUpperCase() === 'MEDIUM' ? 2 : 1) : 
          sev;
        return sum + (sevValue || 0);
      }, 0);

      const averageLatitude = totalLatitude / detections.length;
      const averageLongitude = totalLongitude / detections.length;
      const averageSeverity = totalSeverity / detections.length;

      const verifiedPotholeRef = db.collection("verified_potholes").doc(geohash);

      await verifiedPotholeRef.set(
        {
          latitude: averageLatitude,
          longitude: averageLongitude,
          severity: averageSeverity,
          reportCount: detections.length,
          lastReportedAt: new Date(),
          geohash: geohash,
        },
        { merge: true } // Use merge to create or update
      );

      console.log(`Successfully created/updated verified pothole: ${geohash}`);
    } else {
        // Even if not verifying, we need to ensure the detection has a geohash for future queries.
        // The original document that triggered the function won'''t have one yet.
        if (!data.geohash) {
            await snapshot.ref.update({ geohash: geohash });
        }
    }
  }
);
