'use strict';

const { z } = require('zod');

const healthQuerySchema = z.object({}).strict();

const paginationQuerySchema = z.object({
  page: z.coerce.number().int().min(1).max(10000).optional().default(1),
  limit: z.coerce.number().int().min(1).max(500).optional().default(20),
});

const idParamSchema = z.object({
  id: z.string().min(1).max(128),
});

const emailSchema = z.string().trim().min(5).max(254).email();

const passwordSchema = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .max(128, 'Password must not exceed 128 characters')
  .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
  .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
  .regex(/[0-9]/, 'Password must contain at least one digit');

const authLoginSchema = z.object({
  idToken: z.string().min(1).max(4096),
});

const authRegisterSchema = z.object({
  idToken: z.string().min(1).max(4096),
  firstName: z.string().trim().min(1).max(64).optional(),
  lastName: z.string().trim().min(1).max(64).optional(),
  displayName: z.string().trim().min(1).max(128).optional(),
});

const userListQuerySchema = z.object({
  page: z.coerce.number().int().min(1).max(10000).optional(),
  limit: z.coerce.number().int().min(1).max(500).optional(),
  role: z.enum(['ADMIN', 'OWNER', 'MANAGER', 'CASHIER', 'STORE_ASSISTANT']).optional(),
  status: z.enum(['pending', 'active', 'suspended']).optional(),
  search: z.string().trim().min(1).max(128).optional(),
});

const userStatusSchema = z.object({
  status: z.enum(['pending', 'active', 'suspended']),
}).strict();

const userRoleSchema = z.object({
  role: z.enum(['ADMIN', 'OWNER', 'MANAGER', 'CASHIER', 'STORE_ASSISTANT']),
}).strict();

const ownerForgotPasswordSchema = z.object({
  email: emailSchema,
}).strict();

module.exports = {
  healthQuerySchema,
  paginationQuerySchema,
  idParamSchema,
  emailSchema,
  passwordSchema,
  authLoginSchema,
  authRegisterSchema,
  userListQuerySchema,
  userStatusSchema,
  userRoleSchema,
  ownerForgotPasswordSchema,
};
