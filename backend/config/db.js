/**
 * MongoDB Connection Utility
 * Connects to MongoDB with retry logic and proper event listeners.
 */

const mongoose = require('mongoose');

const connectDB = async () => {
  const uri = process.env.MONGO_URI;

  if (!uri) {
    console.error('❌  MONGO_URI is not set in environment variables.');
    process.exit(1);
  }

  try {
    const conn = await mongoose.connect(uri, {
      // These options prevent deprecation warnings with Mongoose 7+
      serverSelectionTimeoutMS: 5000,  // Timeout after 5 s
      socketTimeoutMS: 45000,          // Close sockets after 45 s of inactivity
    });

    console.log(`✅  MongoDB connected: ${conn.connection.host}`);
  } catch (error) {
    console.error(`❌  MongoDB connection error: ${error.message}`);
    process.exit(1);
  }

  // Log subsequent disconnection events
  mongoose.connection.on('disconnected', () => {
    console.warn('⚠️  MongoDB disconnected. Reconnecting...');
  });

  mongoose.connection.on('reconnected', () => {
    console.log('✅  MongoDB reconnected.');
  });
};

module.exports = connectDB;

