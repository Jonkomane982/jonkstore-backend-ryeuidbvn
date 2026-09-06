'use strict';

const axios = require('axios');
const { logger } = require('../utils/logger');
const { AppError } = require('../utils/errors');

/**
 * Service to communicate with the Python AI Engine (JonkAI).
 */
class AIGatewayService {
  constructor() {
    this.baseUrl = process.env.JONKAI_ENGINE_URL || 'http://localhost:8000';
    this.client = axios.create({
      baseURL: this.baseUrl,
      timeout: 30000,
    });
  }

  /**
   * Forwards a chat/vision request to the Python AI Engine.
   */
  async askJonk({ businessId, userId, message, image, threadId }) {
    try {
      const response = await this.client.post('/chat/message', {
        business_id: businessId,
        user_id: userId,
        message,
        image_b64: image,
        thread_id: threadId
      });

      return response.data.response;
    } catch (err) {
      logger.error({ err, businessId }, 'AI Gateway: Chat request failed');
      throw new AppError('Jonk AI is temporarily unavailable', 503, 'AI_SERVICE_UNAVAILABLE');
    }
  }

  /**
   * Triggers a specific analytical task.
   */
  async runTask(taskType, businessId, params = {}) {
    const endpointMap = {
      FORECAST: '/forecast/sales',
      ANOMALY: '/anomalies/detect',
      RECOMMEND: '/recommendations/generate'
    };

    const endpoint = endpointMap[taskType];
    if (!endpoint) throw new Error(`Unknown AI task type: ${taskType}`);

    try {
      const response = await this.client.post(endpoint, {
        business_id: businessId,
        ...params
      });
      return response.data;
    } catch (err) {
      logger.error({ err, taskType }, 'AI Gateway: Task execution failed');
      throw new AppError('Intelligence engine task failed', 502, 'AI_TASK_FAILED');
    }
  }
}

module.exports = new AIGatewayService();
