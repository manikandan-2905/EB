/**
 * Error-handling middleware
 * Catches errors thrown from async route handlers.
 */

// eslint-disable-next-line no-unused-vars
const errorHandler = (err, req, res, next) => {
  console.error('[ErrorHandler]', err.stack || err.message);

  const statusCode = err.statusCode || 500;
  return res.status(statusCode).json({
    success: false,
    message: err.message || 'Internal Server Error',
  });
};

module.exports = errorHandler;

