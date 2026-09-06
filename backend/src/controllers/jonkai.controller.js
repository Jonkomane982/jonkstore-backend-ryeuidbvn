'use strict';

const ingestionService = require('../services/jonkai/ingestion.service');
const { asyncHandler } = require('../utils/helpers');
const { logger } = require('../utils/logger');

/**
 * Controller for JonkAI Ingestion and Conversational Gateway.
 */
class JonkAIController {
  /**
   * Endpoint for ingesting a single business event.
   */
  ingestEvent = asyncHandler(async (req, res) => {
    const { businessId } = req; // Attached by tenant middleware
    if (!businessId) {
      return res.status(403).json({ success: false, message: 'Business access is required' });
    }
    const eventData = { ...req.body, businessId };

    const result = await ingestionService.ingestEvent(eventData);

    return res.status(202).json({
      success: true,
      data: result
    });
  });

  /**
   * Endpoint for batch ingestion.
   */
  ingestBatch = asyncHandler(async (req, res) => {
    const { businessId } = req;
    if (!businessId) {
      return res.status(403).json({ success: false, message: 'Business access is required' });
    }
    const { events } = req.body;

    if (!Array.isArray(events)) {
      return res.status(400).json({ success: false, message: 'Events must be an array' });
    }

    const result = await ingestionService.ingestBatch(events, { businessId });

    return res.status(202).json({
      success: true,
      data: result
    });
  });

  /**
   * Chat with Jonk AI (Text + Vision).
   * Proxies request to the Python AI Engine.
   */
  chat = asyncHandler(async (req, res) => {
    const { message, image, threadId } = req.body;
    const { businessId } = req;
    const userId = req.user.id;

    if (!message && !image) {
      return res.status(400).json({ success: false, message: 'Message or image is required' });
    }

    const response = await req.services.aiGateway.askJonk({
      businessId,
      userId,
      message,
      image,
      threadId
    });

    res.status(200).json({
      success: true,
      data: { response }
    });
  });
}

module.exports = new JonkAIController();
