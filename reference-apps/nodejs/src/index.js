/**
 * Node.js Reference API - Main Entry Point
 *
 * Demonstrates infrastructure integration patterns using Express.
 */

const express = require('express');
const helmet = require('helmet');
const { register: prometheusRegister } = require('prom-client');
const config = require('./config');
const { logger, loggingMiddleware } = require('./middleware/logging');
const { corsMiddleware } = require('./middleware/cors');

// Import routes
const healthRoutes = require('./routes/health');
const vaultRoutes = require('./routes/vault');
const databaseRoutes = require('./routes/database');
const cacheRoutes = require('./routes/cache');
const messagingRoutes = require('./routes/messaging');

const app = express();

// Security middleware
app.use(helmet());

// CORS
app.use(corsMiddleware);

// Body parsing
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Logging middleware
app.use(loggingMiddleware);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    name: config.app.name,
    version: config.app.version,
    language: config.app.language,
    framework: config.app.framework,
    description: 'Node.js reference implementation for infrastructure integration',
    endpoints: {
      health: '/health',
      vault_examples: '/examples/vault',
      database_examples: '/examples/database',
      cache_examples: '/examples/cache',
      messaging_examples: '/examples/messaging',
      metrics: '/metrics'
    },
    documentation: 'See README.md for usage examples'
  });
});

// Mount routes
app.use('/health', healthRoutes);
app.use('/examples/vault', vaultRoutes);
app.use('/examples/database', databaseRoutes);
app.use('/examples/cache', cacheRoutes);
app.use('/examples/messaging', messagingRoutes);

// Prometheus metrics endpoint
app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', prometheusRegister.contentType);
    res.end(await prometheusRegister.metrics());
  } catch (error) {
    res.status(500).end(error);
  }
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Cannot ${req.method} ${req.path}`,
    requestId: req.requestId
  });
});

// Error handler
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', {
    error: err.message,
    stack: err.stack,
    requestId: req.requestId
  });

  res.status(err.status || 500).json({
    error: 'Internal Server Error',
    message: config.debug ? err.message : 'An error occurred',
    requestId: req.requestId
  });
});

// Start server
const server = app.listen(config.http.port, config.http.host, () => {
  logger.info(`${config.app.name} started`, {
    port: config.http.port,
    host: config.http.host,
    environment: config.env,
    debug: config.debug
  });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  server.close(() => {
    logger.info('Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  server.close(() => {
    logger.info('Server closed');
    process.exit(0);
  });
});

module.exports = app;
