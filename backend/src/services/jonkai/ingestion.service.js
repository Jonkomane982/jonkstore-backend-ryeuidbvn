'use strict';

const aiRepository = require('../../repositories/ai.repository');
const { hashPayload } = require('../../utils/helpers');
const { logger } = require('../../utils/logger');

/**
 * JONK AI Ingestion Service.
 * Handles the entry point for data mirroring from various sources.
 */
class IngestionService {
  /**
   * Ingests a single business event.
   *
   * @param {Object} eventData
   * @param {string} eventData.sourceSystem - e.g., 'POS_POSTGRES', 'FIRESTORE'
   * @param {string} eventData.sourceRecordId - UUID of the operational record
   * @param {number} eventData.sourceVersion - Version of the operational record
   * @param {string} eventData.businessId - UUID of the business
   * @param {string} eventData.eventType - e.g., 'SALE_COMPLETED'
   * @param {Object} eventData.payload - The data to mirror
   */
  async ingestEvent(eventData) {
    const {
      sourceSystem, sourceRecordId, sourceVersion,
      businessId, eventType, payload
    } = eventData;

    // 1. Validation
    if (!sourceSystem || !sourceRecordId || !businessId || !eventType || !payload) {
      throw new Error('Invalid event data: missing required fields');
    }

    // 2. Sensitive Data Filtering
    const sanitizedPayload = this._sanitizePayload(payload);

    // 3. Payload Integrity (Hashing)
    const payloadHash = hashPayload(sanitizedPayload);

    // 4. Ingest into Ingestion Layer (with Idempotency Check)
    const ingestRecord = await aiRepository.ingestPayload({
      sourceSystem,
      sourceRecordId,
      sourceVersion,
      businessId,
      eventType,
      payload: sanitizedPayload,
      payloadHash,
    });

    if (!ingestRecord) {
      logger.info({ sourceRecordId, sourceVersion, eventType }, 'AI Ingestion: Duplicate event detected and skipped');
      return { status: 'SKIPPED', message: 'Duplicate event' };
    }

    logger.info({ ingestId: ingestRecord.id }, 'AI Ingestion: Event accepted');

    // 5. Lineage Log
    await aiRepository.logPipelineStep(
      ingestRecord.id,
      businessId,
      'INGESTION',
      'ACCEPTED',
      `Event ${eventType} received from ${sourceSystem}`
    );

    return { id: ingestRecord.id, status: ingestRecord.status };
  }

  /**
   * Batch ingestion for synchronization.
   */
  async ingestBatch(events, context) {
    const results = {
      total: events.length,
      accepted: 0,
      skipped: 0,
      failed: 0,
      errors: []
    };

    for (const event of events) {
      try {
        const res = await this.ingestEvent({ ...event, businessId: context.businessId });
        if (res.status === 'SKIPPED') results.skipped++;
        else results.accepted++;
      } catch (err) {
        results.failed++;
        results.errors.push({ recordId: event.sourceRecordId, error: err.message });
        logger.error({ err, event }, 'AI Ingestion: Batch item failed');
      }
    }

    return results;
  }

  /**
   * Removes sensitive fields that must never enter the AI database.
   */
  _sanitizePayload(payload) {
    const sensitiveFields = [
      'password', 'password_hash', 'pin', 'pin_hash',
      'token', 'access_token', 'refresh_token', 'secret',
      'api_key', 'firebase_uid', 'otp'
    ];

    const sanitized = { ...payload };

    const filter = (obj) => {
      for (const key in obj) {
        if (sensitiveFields.includes(key.toLowerCase())) {
          delete obj[key];
        } else if (typeof obj[key] === 'object' && obj[key] !== null) {
          filter(obj[key]);
        }
      }
    };

    filter(sanitized);
    return sanitized;
  }
}

module.exports = new IngestionService();
