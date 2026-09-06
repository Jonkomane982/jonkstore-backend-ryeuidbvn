'use strict';

const BEGIN_RSA = '-----BEGIN PRIVATE KEY-----';
const END_RSA = '-----END PRIVATE KEY-----';
const BEGIN_LEGACY = '-----BEGIN RSA PRIVATE KEY-----';
const END_LEGACY = '-----END RSA PRIVATE KEY-----';

function isValidPem(key) {
  if (!key || typeof key !== 'string') return false;
  const hasStandard = key.includes(BEGIN_RSA) && key.includes(END_RSA);
  const hasLegacy = key.includes(BEGIN_LEGACY) && key.includes(END_LEGACY);
  if (!hasStandard && !hasLegacy) return false;
  const begin = hasStandard ? BEGIN_RSA : BEGIN_LEGACY;
  const end = hasStandard ? END_RSA : END_LEGACY;
  const beginIdx = key.indexOf(begin);
  const endIdx = key.indexOf(end);
  if (endIdx <= beginIdx + begin.length) return false;
  const body = key.slice(beginIdx + begin.length, endIdx).replace(/\s/g, '');
  if (body.length < 200) return false;
  if (!/^[A-Za-z0-9+/=]+$/.test(body)) return false;
  return true;
}

function extractPem(key) {
  if (!key) return '';
  const patterns = [
    { b: BEGIN_RSA, e: END_RSA },
    { b: BEGIN_LEGACY, e: END_LEGACY },
  ];
  for (const { b, e } of patterns) {
    const bi = key.indexOf(b);
    const ei = key.indexOf(e);
    if (bi !== -1 && ei > bi) {
      const body = key.slice(bi + b.length, ei).replace(/\s+/g, '\n');
      const cleaned = body.replace(/\n{2,}/g, '\n').replace(/^\n+|\n+$/g, '');
      return `${b}\n${cleaned}\n${e}\n`;
    }
  }
  return '';
}

function getPrivateKey() {
  let key = process.env.FIREBASE_PRIVATE_KEY || '';

  if (!key && process.env.FIREBASE_PRIVATE_KEY_BASE64) {
    try {
      let b64 = String(process.env.FIREBASE_PRIVATE_KEY_BASE64);
      b64 = b64.replace(/\\n/g, '').replace(/\r?\n/g, '').replace(/\s+/g, '');
      b64 = b64.replace(/[^A-Za-z0-9+/=]/g, '');
      const pad = (4 - (b64.length % 4)) % 4;
      if (pad) b64 += '='.repeat(pad);
      key = Buffer.from(b64, 'base64').toString('utf8');
    } catch {
      key = '';
    }
  }

  if (!key) return '';

  key = key.trim();
  if (key.startsWith('"') && key.endsWith('"')) {
    key = key.substring(1, key.length - 1);
  } else if (key.startsWith("'") && key.endsWith("'")) {
    key = key.substring(1, key.length - 1);
  }

  key = key.replace(/\\r\\n/g, '\n').replace(/\\n/g, '\n').replace(/\\r/g, '\n');

  if (key.includes(BEGIN_RSA) || key.includes(BEGIN_LEGACY)) {
    key = extractPem(key);
  }

  return isValidPem(key) ? key : '';
}

const privateKey = getPrivateKey();
const projectId = (process.env.FIREBASE_PROJECT_ID || '').trim();
const clientEmail = (process.env.FIREBASE_CLIENT_EMAIL || '').trim();

const isConfigured = Boolean(
  projectId &&
  /^[a-z0-9-]+$/.test(projectId) &&
  clientEmail &&
  /@/.test(clientEmail) &&
  privateKey &&
  isValidPem(privateKey)
);

const firebaseConfig = Object.freeze({
  isConfigured,
  projectId,
  clientEmail,
  privateKey,
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET || `${projectId}.firebasestorage.app`,
  databaseURL: `https://${projectId}.firebaseio.com`,
});

module.exports = firebaseConfig;
