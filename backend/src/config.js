'use strict';

/* Central configuration, validated once at boot so misconfig fails fast. */

const dotenv = require('dotenv');

dotenv.config();

function required(name) {
  const value = (process.env[name] || '').trim();
  if (!value) {
    throw new Error(`Missing required env var ${name} (see .env.example)`);
  }
  return value;
}

const config = {
  port: parseInt(process.env.PORT || '3001', 10),
  supabaseUrl: required('SUPABASE_URL'),
  supabaseServiceKey: required('SUPABASE_SERVICE_ROLE_KEY'),
  odooBase: (process.env.ODOO_BASE || 'https://horizon.ucp.edu.pk').replace(/\/+$/, ''),
  corsOrigin: process.env.CORS_ORIGIN || '*',
};

module.exports = { config, required };
