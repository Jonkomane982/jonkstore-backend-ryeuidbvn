'use strict';

let admin = null;
try {
  admin = require('firebase-admin');
} catch (_e) {
  admin = null;
}

const firebaseConfig = require('../config/firebase');
const { logger, childLogger } = require('../utils/logger');
const { AppError, AuthenticationError, ServiceUnavailableError } = require('../utils/errors');

class FirebaseAdminService {
  constructor(config = firebaseConfig) {
    this.config = config;
    this.app = null;
    this._initialized = false;
    this.logger = childLogger({ service: 'firebase-admin' });
  }

  isInitialized() {
    return this._initialized && this.app !== null;
  }

  isConfigured() {
    return this.config.isConfigured;
  }

  initialize() {
    if (this._initialized) {
      return this.app;
    }
    this._initialized = true;
    if (!admin) {
      this.logger.warn('firebase-admin package not installed; install optionalDependencies to enable Firebase features');
      this.app = null;
      return null;
    }
    if (!this.isConfigured()) {
      this.logger.warn({
        projectId: this.config.projectId || '(unset)',
        clientEmail: this.config.clientEmail || '(unset)',
        hasPrivateKey: Boolean(this.config.privateKey),
      }, 'Firebase Admin credentials missing or invalid; authentication features unavailable');
      this.app = null;
      return null;
    }
    try {
      const credential = admin.credential.cert({
        projectId: this.config.projectId,
        clientEmail: this.config.clientEmail,
        privateKey: this.config.privateKey,
      });
      const appOptions = {
        credential,
        projectId: this.config.projectId,
      };
      if (this.config.databaseURL) {
        appOptions.databaseURL = this.config.databaseURL;
      }
      if (this.config.storageBucket) {
        appOptions.storageBucket = this.config.storageBucket;
      }
      const existingApp = admin.apps.length ? admin.apps.find(a => a.name === 'jonkstore-backend') : null;
      if (existingApp) {
        this.app = existingApp;
      } else {
        this.app = admin.initializeApp(appOptions, 'jonkstore-backend');
      }
      this.logger.info({ projectId: this.config.projectId }, 'Firebase Admin initialized');
      return this.app;
    } catch (err) {
      const code = (err && err.code) || 'UNKNOWN';
      const message = (err && err.message) || String(err);
      this.logger.warn(
        { code, message: message.slice(0, 200) },
        'Firebase Admin initialization failed (non-fatal); auth features unavailable'
      );
      this.app = null;
      return null;
    }
  }

  auth() {
    if (!this._initialized) this.initialize();
    if (!this.app) return null;
    return this.app.auth();
  }

  firestore() {
    if (!this._initialized) this.initialize();
    if (!this.app) return null;
    return this.app.firestore();
  }

  storage() {
    if (!this._initialized) this.initialize();
    if (!this.app) return null;
    return this.app.storage();
  }

  /**
   * Upserts a document into a Firestore collection.
   */
  async upsert(collection, docId, data) {
    const db = this.firestore();
    if (!db) {
      this.logger.warn({ collection, docId }, 'Firestore unavailable, skipping upsert');
      return null;
    }
    try {
      const docRef = db.collection(collection).doc(docId);
      await docRef.set({
        ...data,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      return docId;
    } catch (err) {
      this.logger.error({ err, collection, docId }, 'Firestore upsert failed');
      throw new AppError('Data synchronization failed', 500, 'FIRESTORE_ERROR');
    }
  }

  async verifyIdToken(idToken, checkRevoked = false) {
    const authInstance = this.auth();
    if (!authInstance) {
      throw new ServiceUnavailableError(
        'Firebase authentication service is not configured',
        'FIREBASE_AUTH_UNAVAILABLE'
      );
    }
    if (!idToken || typeof idToken !== 'string' || idToken.length < 10) {
      throw new AuthenticationError('Invalid token format', 'INVALID_TOKEN');
    }
    try {
      return await authInstance.verifyIdToken(idToken, checkRevoked);
    } catch (err) {
      const code = err && err.code ? err.code : 'unknown';
      if (code === 'auth/id-token-expired') {
        throw new AuthenticationError('Token expired', 'TOKEN_EXPIRED');
      }
      if (code === 'auth/id-token-revoked') {
        throw new AuthenticationError('Token revoked', 'TOKEN_REVOKED');
      }
      if (code === 'auth/argument-error' || code === 'auth/invalid-id-token' || code === 'auth/invalid-credential') {
        throw new AuthenticationError('Invalid token format', 'INVALID_TOKEN');
      }
      this.logger.debug({ code }, 'Token verification failed');
      throw new AuthenticationError('Authentication failed', 'AUTH_FAILED');
    }
  }

  async getUserByUid(uid) {
    const authInstance = this.auth();
    if (!authInstance) {
      throw new ServiceUnavailableError('Firebase Auth service unavailable', 'FIREBASE_UNAVAILABLE');
    }
    return authInstance.getUser(uid);
  }

  async setCustomUserClaims(uid, claims) {
    const authInstance = this.auth();
    if (!authInstance) {
      throw new ServiceUnavailableError('Firebase Auth service unavailable', 'FIREBASE_UNAVAILABLE');
    }
    return authInstance.setCustomUserClaims(uid, claims || {});
  }

  async createUser(userRecord) {
    const authInstance = this.auth();
    if (!authInstance) {
      throw new ServiceUnavailableError('Firebase Auth service unavailable', 'FIREBASE_UNAVAILABLE');
    }
    return authInstance.createUser(userRecord);
  }

  async generateEmailVerificationLink(email) {
    const authInstance = this.auth();
    if (!authInstance) {
      throw new ServiceUnavailableError('Firebase Auth service unavailable', 'FIREBASE_UNAVAILABLE');
    }
    return authInstance.generateEmailVerificationLink(email);
  }

  async generatePasswordResetLink(email) {
    const authInstance = this.auth();
    if (!authInstance) {
      throw new ServiceUnavailableError('Firebase Auth service unavailable', 'FIREBASE_UNAVAILABLE');
    }
    return authInstance.generatePasswordResetLink(email);
  }
}

const firebaseAdminService = new FirebaseAdminService();

module.exports = {
  FirebaseAdminService,
  firebaseAdminService,
};
