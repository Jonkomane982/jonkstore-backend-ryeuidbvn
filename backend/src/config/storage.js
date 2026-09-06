'use strict';

const path = require('path');

function parseNumber(value, fallback) {
  const num = Number(value);
  return Number.isFinite(num) ? num : fallback;
}

function parseCsvList(value) {
  if (!value) return [];
  return String(value)
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

const uploadRoot = process.env.STORAGE_UPLOAD_DIR || './uploads';
const absoluteUploadRoot = path.isAbsolute(uploadRoot)
  ? uploadRoot
  : path.resolve(process.cwd(), uploadRoot);

const storageConfig = Object.freeze({
  uploadRoot: absoluteUploadRoot,
  directories: Object.freeze({
    products: path.join(absoluteUploadRoot, 'products'),
    customers: path.join(absoluteUploadRoot, 'customers'),
    businesses: path.join(absoluteUploadRoot, 'businesses'),
    receipts: path.join(absoluteUploadRoot, 'receipts'),
  }),
  maxFileSizeBytes: parseNumber(process.env.STORAGE_MAX_FILE_SIZE_BYTES, 10 * 1024 * 1024),
  allowedImageMimeTypes: parseCsvList(process.env.STORAGE_ALLOWED_IMAGE_MIMES).length
    ? parseCsvList(process.env.STORAGE_ALLOWED_IMAGE_MIMES)
    : ['image/jpeg', 'image/png', 'image/webp', 'image/gif'],
  allowedDocumentMimeTypes: parseCsvList(process.env.STORAGE_ALLOWED_DOC_MIMES).length
    ? parseCsvList(process.env.STORAGE_ALLOWED_DOC_MIMES)
    : ['application/pdf'],
  getAllowedMimeTypes() {
    return [...storageConfig.allowedImageMimeTypes, ...storageConfig.allowedDocumentMimeTypes];
  },
  serveStatic: false,
});

module.exports = storageConfig;
