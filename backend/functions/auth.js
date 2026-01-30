const {onCall} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");

initializeApp();

const db = getFirestore();
const auth = getAuth();

// Secret key for JWT signing (should be stored in environment variables in production)
const JWT_SECRET = process.env.JWT_SECRET || "your-secret-key-change-in-production";
const JWT_EXPIRY = 86400; // 24 hours in seconds

/**
 * Municipality Admin Login
 * 
 * Request body:
 * {
 *   "email": "admin@city.gov",
 *   "password": "securePassword123"
 * }
 * 
 * Response (success):
 * {
 *   "success": true,
 *   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
 *   "user": {
 *     "id": "user_doc_id",
 *     "email": "admin@city.gov",
 *     "name": "John Doe",
 *     "role": "MUNICIPAL_ADMIN",
 *     "municipality_id": "city_doc_id"
 *   },
 *   "expiresIn": 86400
 * }
 */
exports.municipalityLogin = onCall(
  {
    secrets: ["JWT_SECRET"],
    enforceAppCheck: false, // Allow non-app-check requests for login
    region: "us-central1",
  },
  async (request) => {
    const {email, password} = request.data;

    // Step 1: Validate input
    if (!email || !password) {
      throw new Error("Email and password are required");
    }

    if (!email.includes("@")) {
      throw new Error("Invalid email format");
    }

    if (password.length < 6) {
      throw new Error("Invalid email or password");
    }

    try {
      // Step 2: Query municipality_users collection
      const usersRef = db.collection("municipality_users");
      const querySnapshot = await usersRef.where("email", "==", email.toLowerCase()).get();

      if (querySnapshot.empty) {
        // Don't reveal if email exists for security
        throw new Error("Invalid email or password");
      }

      const userDoc = querySnapshot.docs[0];
      const userData = userDoc.data();
      const userId = userDoc.id;

      // Step 3: Check if account is active
      if (!userData.active) {
        throw new Error("Your account is inactive. Contact administrator.");
      }

      // Step 4: Verify password hash
      const passwordMatch = await bcrypt.compare(password, userData.password_hash);
      if (!passwordMatch) {
        throw new Error("Invalid email or password");
      }

      // Step 5: Verify municipality is verified
      const municipalityRef = db.collection("municipalities").doc(userData.municipality_id);
      const municipalityDoc = await municipalityRef.get();

      if (!municipalityDoc.exists || !municipalityDoc.data().verified) {
        throw new Error("Municipality not verified yet. Contact support.");
      }

      // Step 6: Generate JWT token
      const issuedAt = Math.floor(Date.now() / 1000);
      const expiresAt = issuedAt + JWT_EXPIRY;

      const token = jwt.sign(
        {
          sub: userId,
          email: userData.email,
          name: userData.name,
          role: userData.role,
          municipality_id: userData.municipality_id,
          iat: issuedAt,
          exp: expiresAt,
        },
        process.env.JWT_SECRET || JWT_SECRET,
        {algorithm: "HS256"}
      );

      // Step 7: Update last_login timestamp
      await userDoc.ref.update({
        last_login: new Date(),
      });

      // Step 8: Log authentication attempt (audit trail)
      await db.collection("auth_logs").add({
        email: userData.email,
        user_id: userId,
        municipality_id: userData.municipality_id,
        action: "LOGIN_SUCCESS",
        timestamp: new Date(),
        ip_address: request.rawRequest?.ip || "unknown",
      });

      // Step 9: Return success response
      return {
        success: true,
        token: token,
        user: {
          id: userId,
          email: userData.email,
          name: userData.name,
          role: userData.role,
          municipality_id: userData.municipality_id,
        },
        expiresIn: JWT_EXPIRY,
      };
    } catch (error) {
      // Log failed attempt
      await db.collection("auth_logs").add({
        email: email,
        action: "LOGIN_FAILED",
        reason: error.message,
        timestamp: new Date(),
        ip_address: request.rawRequest?.ip || "unknown",
      });

      throw new Error(error.message);
    }
  }
);

/**
 * Verify JWT token validity
 * Used by frontend to check if stored token is still valid
 */
exports.verifyToken = onCall(
  {
    region: "us-central1",
  },
  async (request) => {
    const {token} = request.data;

    if (!token) {
      throw new Error("Token is required");
    }

    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET || JWT_SECRET);
      return {
        success: true,
        valid: true,
        decoded: {
          userId: decoded.sub,
          email: decoded.email,
          role: decoded.role,
          expiresAt: decoded.exp * 1000, // Convert to milliseconds
        },
      };
    } catch (error) {
      return {
        success: false,
        valid: false,
        reason: error.message,
      };
    }
  }
);

/**
 * Logout - Log the logout event
 */
exports.municipalityLogout = onCall(
  {
    region: "us-central1",
  },
  async (request) => {
    const {token} = request.data;

    if (token) {
      try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET || JWT_SECRET);
        await db.collection("auth_logs").add({
          user_id: decoded.sub,
          email: decoded.email,
          municipality_id: decoded.municipality_id,
          action: "LOGOUT",
          timestamp: new Date(),
        });
      } catch (error) {
        console.error("Error logging logout:", error);
      }
    }

    return {success: true};
  }
);

/**
 * Create a new municipality user (SUPER_ADMIN only)
 * This should be called via a protected endpoint
 */
exports.createMunicipalityUser = onCall(
  {
    region: "us-central1",
  },
  async (request) => {
    const {email, password, name, role, municipality_id, createdByToken} = request.data;

    // Verify that caller is SUPER_ADMIN
    if (!createdByToken) {
      throw new Error("Unauthorized: Only SUPER_ADMIN can create users");
    }

    try {
      const decoded = jwt.verify(createdByToken, process.env.JWT_SECRET || JWT_SECRET);
      if (decoded.role !== "SUPER_ADMIN") {
        throw new Error("Unauthorized: Only SUPER_ADMIN can create users");
      }

      // Validate inputs
      if (!email || !password || !name || !role || !municipality_id) {
        throw new Error("Missing required fields: email, password, name, role, municipality_id");
      }

      const validRoles = ["SUPER_ADMIN", "MUNICIPAL_ADMIN", "FIELD_ENGINEER"];
      if (!validRoles.includes(role)) {
        throw new Error(`Invalid role. Must be one of: ${validRoles.join(", ")}`);
      }

      // Hash password
      const saltRounds = 10;
      const passwordHash = await bcrypt.hash(password, saltRounds);

      // Create user document
      const userRef = db.collection("municipality_users").doc();
      await userRef.set({
        email: email.toLowerCase(),
        password_hash: passwordHash,
        name: name,
        role: role,
        municipality_id: municipality_id,
        active: true,
        created_at: new Date(),
        updated_at: new Date(),
        last_login: null,
      });

      return {
        success: true,
        user_id: userRef.id,
        message: `User ${email} created successfully`,
      };
    } catch (error) {
      throw new Error(error.message);
    }
  }
);
