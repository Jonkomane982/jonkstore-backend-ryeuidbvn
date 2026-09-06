'use strict';

const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const { ValidationError } = require('./errors');

const PATH_TRAVERSAL_RE = /\.\.[/\\]/;

function sanitizeFilename(originalName) {
  if (!originalName || typeof originalName !== 'string') {
    return null;
  }
  const ext = path.extname(originalName).toLowerCase();
  const safeExt = ext.replace(/[^a-z0-9.]/g, '');
  const randomToken = crypto.randomBytes(8).toString('hex');
  const timestamp = Date.now();
  const uuid = uuidv4().replace(/-/g, '').slice(0, 8);
  return `${timestamp}-${uuid}-${randomToken}${safeExt}`;
}

function isPathSafe(targetDir, fullPath) {
  const resolvedDir = path.resolve(targetDir);
  const resolvedFile = path.resolve(fullPath);
  const relative = path.relative(resolvedDir, resolvedFile);
  if (PATH_TRAVERSAL_RE.test(relative)) return false;
  return !relative.startsWith('..') && !path.isAbsolute(relative);
}

function ensureDirSync(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true, mode: 0o750 });
  }
  return dirPath;
}

function validateFileMimeType(file, allowedMimeTypes) {
  if (!file) return false;
  const mimetype = (file.mimetype || '').toLowerCase();
  return Array.isArray(allowedMimeTypes) && allowedMimeTypes.includes(mimetype);
}

function validateFileExtension(fileName, allowedExtensions) {
  if (!fileName || !Array.isArray(allowedExtensions)) return false;
  const ext = path.extname(fileName).toLowerCase();
  return allowedExtensions.includes(ext);
}

function buildSafeFilenameForCategory(originalName, category) {
  const safe = sanitizeFilename(originalName);
  if (!safe) {
    throw new ValidationError('Invalid filename provided');
  }
  const categoryPrefix = String(category || 'misc').replace(/[^a-z0-9_-]/gi, '').toLowerCase();
  return `${categoryPrefix ? categoryPrefix + '_' : ''}${safe}`;
}

module.exports = {
  sanitizeFilename,
  isPathSafe,
  ensureDirSync,
  validateFileMimeType,
  validateFileExtension,
  buildSafeFilenameForCategory,
};
