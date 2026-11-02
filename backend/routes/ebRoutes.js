/**
 * EB Records Routes
 * Defines all REST endpoints and attaches express-validator middleware.
 */

const express = require('express');
const { body } = require('express-validator');
const router = express.Router();
const {
  checkEbNumber,
  createRecord,
  updateSchedule,
  getScheduledRecords,
  searchRecords,
  getLatestRecords,
  deleteRecord,
} = require('../controllers/ebController');

// ─── Validation Rules ────────────────────────────────────────────────────────

const createRecordValidation = [
  body('ebNumber')
    .notEmpty().withMessage('EB Number is required.')
    .isLength({ min: 3, max: 30 }).withMessage('EB Number must be between 3 and 30 characters.'),

  body('longitude')
    .notEmpty().withMessage('Longitude is required.')
    .isFloat({ min: -180, max: 180 }).withMessage('Longitude must be between -180 and 180.'),

  body('latitude')
    .notEmpty().withMessage('Latitude is required.')
    .isFloat({ min: -90, max: 90 }).withMessage('Latitude must be between -90 and 90.'),

  body('consumerName')
    .optional()
    .isLength({ max: 100 }).withMessage('Consumer name must be at most 100 characters.'),

  body('landmarkNotes')
    .optional()
    .isLength({ max: 300 }).withMessage('Landmark notes must be at most 300 characters.'),

  body('address')
    .optional()
    .isLength({ max: 500 }).withMessage('Address must be at most 500 characters.'),

  body('scheduledDate')
    .optional(),
];

// ─── Routes ──────────────────────────────────────────────────────────────────

// GET  /api/eb-records/check-eb?ebNumber=07-123-004-567 (check if EB exists)
router.get('/check-eb', checkEbNumber);

// GET  /api/eb-records/scheduled?date=2026-11-02 (get scheduled house visits)
router.get('/scheduled', getScheduledRecords);

// GET  /api/eb-records/search?query=07-123
router.get('/search', searchRecords);

// GET  /api/eb-records  — latest 50
router.get('/', getLatestRecords);

// POST /api/eb-records  — create unique record
router.post('/', createRecordValidation, createRecord);

// PATCH / PUT /api/eb-records/:id/schedule — schedule a visit
router.patch('/:id/schedule', updateSchedule);
router.put('/:id/schedule', updateSchedule);

// DELETE /api/eb-records/:id
router.delete('/:id', deleteRecord);

module.exports = router;
