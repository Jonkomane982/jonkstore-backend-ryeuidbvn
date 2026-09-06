'use strict';

const multer = require('multer');
const path = require('path');
const storageConfig = require('../config/storage');
const { logger, childLogger } = require('../utils/logger');
const { ValidationError, AppError } = require('../utils/errors');
const {
  sanitizeFilename,
  ensureDirSync,
  validateFileMimeType,
  buildSafeFilenameForCategory,
  isPathSafe,
} = require('../utils/file');

const CATEGORY_MAP = Object.freeze({
  product: 'products',
  customer: 'customers',
  business: 'businesses',
  receipt: 'receipts',
  products: 'products',
  customers: 'customers',
  businesses: 'businesses',
  receipts: 'receipts',
});

class StorageService {
  constructor(config = storageConfig) {
    this.config = config;
    this._uploaders = new Map();
    this._initialized = false;
    this.logger = childLogger({ service: 'storage' });
  }

  initialize() {
    if (this._initialized) return;
    try {
      ensureDirSync(this.config.uploadRoot);
      for (const dir of Object.values(this.config.directories)) {
        ensureDirSync(dir);
      }
      this._initialized = true;
      this.logger.info({ root: this.config.uploadRoot }, 'Storage service initialized');
    } catch (err) {
      this.logger.error({ err }, 'Failed to initialize storage directories');
      throw new AppError('Failed to initialize storage', 500, 'STORAGE_INIT_FAILED');
    }
  }

  resolveCategoryDir(category) {
    const normalized = CATEGORY_MAP[category];
    if (!normalized || !this.config.directories[normalized]) {
      throw new ValidationError(`Invalid storage category: ${category}`);
    }
    const dir = this.config.directories[normalized];
    ensureDirSync(dir);
    return dir;
  }

  _buildDiskStorage(categoryDir) {
    return multer.diskStorage({
      destination(_req, _file, cb) {
        cb(null, categoryDir);
      },
      filename(_req, file, cb) {
        try {
          const sanitized = buildSafeFilenameForCategory(
            file.originalname,
            path.basename(categoryDir)
          );
          cb(null, sanitized);
        } catch (err) {
          cb(err);
        }
      },
    });
  }

  _buildFileFilter(allowedMimeTypes) {
    return function fileFilter(_req, file, cb) {
      if (!validateFileMimeType(file, allowedMimeTypes)) {
        return cb(new ValidationError(
          `Invalid file type: ${file.mimetype}. Allowed: ${allowedMimeTypes.join(', ')}`,
          [],
          'INVALID_FILE_TYPE'
        ));
      }
      cb(null, true);
    };
  }

  getUploader(category, options = {}) {
    const categoryDir = this.resolveCategoryDir(category);
    const cacheKey = `${category}:${options.fieldName || 'file'}:${options.maxCount || 1}`;
    if (this._uploaders.has(cacheKey)) {
      return this._uploaders.get(cacheKey);
    }
    if (!this._initialized) this.initialize();
    const allowedMimeTypes = options.allowedMimeTypes || this.config.getAllowedMimeTypes();
    const storage = this._buildDiskStorage(categoryDir);
    const fileFilter = this._buildFileFilter(allowedMimeTypes);
    const limits = {
      fileSize: options.maxFileSizeBytes || this.config.maxFileSizeBytes,
      files: options.maxCount || 1,
      fields: options.maxFields || 100,
    };
    const uploader = multer({
      storage,
      fileFilter,
      limits,
      preservePath: false,
    });
    this._uploaders.set(cacheKey, uploader);
    return uploader;
  }

  single(category, fieldName = 'file', options = {}) {
    const uploader = this.getUploader(category, { ...options, fieldName, maxCount: 1 });
    return uploader.single(fieldName);
  }

  array(category, fieldName = 'files', maxCount = 10, options = {}) {
    const uploader = this.getUploader(category, { ...options, fieldName, maxCount });
    return uploader.array(fieldName, maxCount);
  }

  getSafeFilePath(category, filename) {
    const dir = this.resolveCategoryDir(category);
    const safeName = sanitizeFilename(filename) || filename;
    const fullPath = path.join(dir, safeName);
    if (!isPathSafe(dir, fullPath)) {
      throw new ValidationError('Unsafe path detected');
    }
    return fullPath;
  }

  getFileMetadata(file) {
    if (!file) return null;
    return {
      originalName: file.originalname,
      storedName: file.filename,
      mimetype: file.mimetype,
      sizeBytes: file.size,
      path: file.path,
      encoding: file.encoding,
    };
  }
}

const storageService = new StorageService();

module.exports = {
  StorageService,
  storageService,
};
