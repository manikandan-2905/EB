/**
 * EB Wireman Assistant — Express Server Entry Point
 */

require('dotenv').config();

const express = require('express');
const helmet  = require('helmet');
const cors    = require('cors');

const connectDB   = require('./config/db');
const ebRoutes    = require('./routes/ebRoutes');
const errorHandler = require('./middleware/errorHandler');

// ─── App Setup ───────────────────────────────────────────────────────────────
const app  = express();
const PORT = process.env.PORT || 5000;

// ─── Security & Parsing Middleware ───────────────────────────────────────────
app.use(helmet());   // Sets secure HTTP headers
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*', // Lock down in production
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
}));
app.use(express.json({ limit: '10kb' }));       // Parse JSON bodies (max 10 KB)
app.use(express.urlencoded({ extended: false }));

// ─── Health Check ────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ─── API Routes ──────────────────────────────────────────────────────────────
app.use('/api/eb-records', ebRoutes);

// ─── 404 Handler ─────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ success: false, message: `Route ${req.originalUrl} not found.` });
});

// ─── Global Error Handler ────────────────────────────────────────────────────
app.use(errorHandler);

// ─── Start Server ────────────────────────────────────────────────────────────
const startServer = async () => {
  await connectDB();
  app.listen(PORT, () => {
    console.log(`🚀  Server running on http://localhost:${PORT}`);
  });
};

startServer();

