'use strict';

const nodemailer = require('nodemailer');
const smtpConfig = require('../config/smtp');
const environment = require('../config/environment');
const { logger, childLogger } = require('../utils/logger');
const { AppError, ValidationError } = require('../utils/errors');
const { emailSchema } = require('../validators/common.validators');

class EmailService {
  constructor(config = smtpConfig, env = environment) {
    this.config = config;
    this.environment = env;
    this._transporter = null;
    this._initialized = false;
    this.logger = childLogger({ service: 'email' });
    this._sent = [];
  }

  isConfigured() {
    return this.config.isConfigured;
  }

  isInitialized() {
    return this._initialized;
  }

  initialize() {
    if (this._initialized) return this._transporter;
    if (!this.isConfigured()) {
      this.logger.warn('SMTP not configured. Emails will be logged only in development and rejected in production.');
      this._initialized = true;
      this._transporter = null;
      return null;
    }
    try {
      const transporterOptions = {
        host: this.config.host,
        port: this.config.port,
        secure: this.config.secure,
        auth: {
          user: this.config.auth.user,
          pass: this.config.auth.pass,
        },
        pool: this.config.pool,
        maxConnections: this.config.maxConnections,
        maxMessages: this.config.maxMessages,
        rateDelta: this.config.rateDelta,
        rateLimit: this.config.rateLimit,
        connectionTimeout: this.config.connectionTimeout,
        greetingTimeout: this.config.greetingTimeout,
        socketTimeout: this.config.socketTimeout,
        logger: environment.isDevelopment,
        debug: environment.isDevelopment,
      };
      if (this.config.secure || this.config.tls) {
        transporterOptions.tls = this.config.tls || {};
      }
      this._transporter = nodemailer.createTransport(transporterOptions);
      this._initialized = true;
      this.logger.info({ host: this.config.host, port: this.config.port }, 'Email service initialized');
      return this._transporter;
    } catch (err) {
      this.logger.error({ err }, 'Failed to initialize email service');
      throw new AppError('Failed to initialize email service', 500, 'EMAIL_INIT_FAILED');
    }
  }

  async verifyConnection() {
    if (!this._initialized) this.initialize();
    if (!this._transporter) {
      if (!this.environment.isProduction) {
        this.logger.info('Email connection verification skipped (SMTP not configured; development mode)');
        return true;
      }
      throw new AppError('Email service unavailable', 503, 'EMAIL_UNAVAILABLE');
    }
    return this._transporter.verify();
  }

  _validateAndNormalize(options) {
    if (!options || typeof options !== 'object') {
      throw new ValidationError('Email options must be an object');
    }
    const rawTo = Array.isArray(options.to) ? options.to : [options.to];
    const to = rawTo.map((addr) => emailSchema.parse(String(addr)));
    if (to.length === 0) {
      throw new ValidationError('At least one recipient (to) is required');
    }
    const subject = String(options.subject || '').trim();
    if (!subject) {
      throw new ValidationError('Email subject is required');
    }
    const text = options.text != null ? String(options.text) : '';
    const html = options.html != null ? String(options.html) : '';
    if (!text && !html) {
      throw new ValidationError('Email must contain at least text or html body');
    }
    return {
      to,
      from: options.from || this.config.defaults.from,
      cc: options.cc || [],
      bcc: options.bcc || [],
      replyTo: options.replyTo || undefined,
      subject,
      text,
      html,
      attachments: Array.isArray(options.attachments) ? options.attachments : [],
      headers: options.headers || {},
    };
  }

  async sendEmail(options) {
    if (!this._initialized) this.initialize();
    const mailData = this._validateAndNormalize(options);
    if (!this._transporter) {
      if (this.environment.isProduction) {
        throw new AppError(
          'Email service unavailable in production without SMTP configuration',
          503,
          'EMAIL_UNAVAILABLE'
        );
      }
      const captured = {
        envelope: {
          from: typeof mailData.from === 'string' ? mailData.from : mailData.from.address,
          to: mailData.to,
        },
        messageId: `dev-${Date.now()}-${Math.random().toString(36).slice(2)}`,
        subject: mailData.subject,
        textPreview: mailData.text.slice(0, 200),
        to: mailData.to,
        sentAt: new Date().toISOString(),
      };
      this._sent.push(captured);
      this.logger.info(
        { to: mailData.to, subject: mailData.subject, messageId: captured.messageId },
        '[DEV MODE] Email not sent via SMTP — captured instead'
      );
      return {
        messageId: captured.messageId,
        accepted: mailData.to,
        rejected: [],
        pending: [],
        response: 'OK (development capture)',
        captured: true,
      };
    }
    try {
      const result = await this._transporter.sendMail(mailData);
      this.logger.info(
        { to: mailData.to, subject: mailData.subject, messageId: result.messageId },
        'Email sent successfully'
      );
      return {
        messageId: result.messageId,
        accepted: result.accepted || [],
        rejected: result.rejected || [],
        pending: result.pending || [],
        response: result.response || '',
        captured: false,
      };
    } catch (err) {
      this.logger.error({ err, to: mailData.to, subject: mailData.subject }, 'Failed to send email');
      throw new AppError(
        'Failed to send email',
        502,
        'EMAIL_SEND_FAILED'
      );
    }
  }

  async sendOwnerOtp({ to, otpCode, expiresAt, businessName }) {
    if (!otpCode || typeof otpCode !== 'string') {
      throw new ValidationError('OTP code is required');
    }
    const subject = `${businessName ? `[${businessName}] ` : ''}Your JonkStore verification code`;
    const expiresText = expiresAt
      ? `This code is valid until ${new Date(expiresAt).toLocaleString()}.`
      : 'This code will expire shortly.';
    const text = [
      `Your JonkStore verification code is: ${otpCode}`,
      '',
      expiresText,
      '',
      'If you did not request this code, please ignore this email.',
      '',
      '— The JonkStore Team',
    ].join('\n');
    const html = `
      <div style="font-family: Arial, sans-serif; line-height: 1.6;">
        <h2>JonkStore Verification Code</h2>
        <p>Your verification code is:</p>
        <div style="font-size: 28px; letter-spacing: 8px; font-weight: bold; padding: 16px; background: #f5f5f5; border-radius: 8px; display: inline-block;">
          ${otpCode}
        </div>
        <p>${expiresText}</p>
        <p style="color: #666;">If you did not request this code, please ignore this email.</p>
        <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;" />
        <p style="color: #999; font-size: 12px;">The JonkStore Team</p>
      </div>
    `;
    return this.sendEmail({
      to,
      subject,
      text,
      html,
    });
  }

  async sendPasswordResetEmail({ to, link }) {
    const subject = 'JonkStore POS — Password Recovery';
    const text = `Follow this link to reset your password: ${link}\n\nThis link will expire shortly.\n\n— The JonkStore Team`;
    const html = `
      <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #374151;">
        <h2>Password Recovery</h2>
        <p>We received a request to reset your password for JonkStore POS.</p>
        <div style="margin: 32px 0;">
          <a href="${link}" style="background: #10b981; color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: bold;">
            Reset Password
          </a>
        </div>
        <p>If the button above doesn't work, copy and paste this link into your browser:</p>
        <p style="word-break: break-all; font-size: 12px; color: #6b7280;">${link}</p>
        <p style="margin-top: 32px; font-size: 13px; color: #9ca3af;">If you did not request this, you can safely ignore this email.</p>
      </div>
    `;
    return this.sendEmail({
      to,
      subject,
      text,
      html,
    });
  }

  getCapturedEmails() {
    return [...this._sent];
  }

  clearCapturedEmails() {
    this._sent = [];
  }

  async shutdown() {
    if (this._transporter && typeof this._transporter.close === 'function') {
      try {
        this._transporter.close();
      } catch (err) {
        this.logger.warn({ err }, 'Error closing email transporter');
      }
    }
    this._initialized = false;
    this._transporter = null;
  }
}

const emailService = new EmailService();

module.exports = {
  EmailService,
  emailService,
};
