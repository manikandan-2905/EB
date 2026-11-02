/**
 * EB Records Controller
 * Handles business logic for creating, updating, searching, scheduling, and listing EB records.
 */

const mongoose = require('mongoose');
const EbRecord = require('../models/EbRecord');
const { validationResult } = require('express-validator');

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/eb-records/check-eb?ebNumber=...
// Checks if an EB number is already registered (for duplicate prevention)
// ─────────────────────────────────────────────────────────────────────────────
exports.checkEbNumber = async (req, res) => {
  try {
    const ebNumber = (req.query.ebNumber || '').trim();
    if (!ebNumber) {
      return res.status(400).json({ success: false, message: 'EB number is required.' });
    }

    const existing = await EbRecord.findOne({ ebNumber });
    return res.status(200).json({
      success: true,
      exists: !!existing,
      message: existing ? 'EB Number already registered!' : 'EB Number is available.',
      data: existing || null,
    });
  } catch (error) {
    console.error('[checkEbNumber]', error);
    return res.status(500).json({ success: false, message: 'Server error while checking EB number.' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/eb-records
// Creates a new EB record with strict UNIQUE check & optional scheduledDate.
// ─────────────────────────────────────────────────────────────────────────────
exports.createRecord = async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(422).json({ success: false, errors: errors.array() });
  }

  try {
    const { ebNumber, consumerName, landmarkNotes, longitude, latitude, address, scheduledDate } = req.body;
    const cleanEb = ebNumber.trim();

    // Check if EB number already exists
    const existing = await EbRecord.findOne({ ebNumber: cleanEb });
    if (existing) {
      return res.status(409).json({
        success: false,
        message: `EB Number "${cleanEb}" is already registered. Duplicates are not allowed.`,
      });
    }

    // GeoJSON stores as [longitude, latitude]
    const coordinates = [parseFloat(longitude), parseFloat(latitude)];

    const newRecord = new EbRecord({
      ebNumber: cleanEb,
      consumerName: consumerName ? consumerName.trim() : '',
      landmarkNotes: landmarkNotes ? landmarkNotes.trim() : '',
      address: address ? address.trim() : '',
      scheduledDate: scheduledDate ? new Date(scheduledDate) : null,
      visitStatus: 'Pending',
      location: {
        type: 'Point',
        coordinates,
      },
    });

    await newRecord.save();

    return res.status(201).json({
      success: true,
      message: 'EB Record registered successfully.',
      data: newRecord,
    });
  } catch (error) {
    console.error('[createRecord]', error);
    return res.status(500).json({ success: false, message: 'Server error while creating record.' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/eb-records/:id/schedule
// Updates or sets a scheduled visit date and status for an EB house.
// ─────────────────────────────────────────────────────────────────────────────
exports.updateSchedule = async (req, res) => {
  try {
    const { id } = req.params;
    const { scheduledDate, visitStatus } = req.body;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ success: false, message: 'Invalid record ID format.' });
    }

    const updateFields = {};
    if (scheduledDate !== undefined) {
      updateFields.scheduledDate = scheduledDate ? new Date(scheduledDate) : null;
    }
    if (visitStatus !== undefined) {
      updateFields.visitStatus = visitStatus;
    }

    const record = await EbRecord.findByIdAndUpdate(
      id,
      { $set: updateFields },
      { new: true, runValidators: true }
    );

    if (!record) {
      return res.status(404).json({ success: false, message: 'Record not found.' });
    }

    return res.status(200).json({
      success: true,
      message: 'Schedule updated successfully.',
      data: record,
    });
  } catch (error) {
    console.error('[updateSchedule]', error);
    return res.status(500).json({ success: false, message: 'Server error while updating schedule.' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/eb-records/scheduled?date=YYYY-MM-DD
// Returns house records scheduled for a particular date (or upcoming if no date).
// ─────────────────────────────────────────────────────────────────────────────
exports.getScheduledRecords = async (req, res) => {
  try {
    const { date } = req.query;
    const filter = {};

    if (date) {
      // Calculate start and end of that specific day
      const targetDate = new Date(date);
      const startOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), 0, 0, 0, 0);
      const endOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), 23, 59, 59, 999);

      filter.scheduledDate = {
        $gte: startOfDay,
        $lte: endOfDay,
      };
    } else {
      // If no specific date passed, get all records that have a scheduled date
      filter.scheduledDate = { $ne: null };
    }

    const records = await EbRecord.find(filter)
      .sort({ scheduledDate: 1, updatedAt: -1 })
      .lean();

    return res.status(200).json({
      success: true,
      count: records.length,
      data: records,
    });
  } catch (error) {
    console.error('[getScheduledRecords]', error);
    return res.status(500).json({ success: false, message: 'Server error while fetching scheduled records.' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/eb-records/search?query=<partial_eb_number_or_address>
// Searches records by EB number, consumer name, landmark, or street address.
// ─────────────────────────────────────────────────────────────────────────────
exports.searchRecords = async (req, res) => {
  try {
    const query = (req.query.query || '').trim();

    if (!query) {
      return res.status(400).json({ success: false, message: 'Search query is required.' });
    }

    const regex = new RegExp(query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');

    const records = await EbRecord.find({
      $or: [
        { ebNumber: { $regex: regex } },
        { consumerName: { $regex: regex } },
        { landmarkNotes: { $regex: regex } },
        { address: { $regex: regex } },
      ],
    })
      .sort({ updatedAt: -1 })
      .limit(50)
      .lean();

    return res.status(200).json({ success: true, count: records.length, data: records });
  } catch (error) {
    console.error('[searchRecords]', error);
    return res.status(500).json({ success: false, message: 'Server error during search.' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/eb-records
// Returns the latest 50 records ordered by most recently updated.
// ─────────────────────────────────────────────────────────────────────────────
exports.getLatestRecords = async (req, res) => {
  try {
    const records = await EbRecord.find({})
      .sort({ updatedAt: -1 })
      .limit(50)
      .lean();

    return res.status(200).json({ success: true, count: records.length, data: records });
  } catch (error) {
    console.error('[getLatestRecords]', error);
    return res.status(500).json({ success: false, message: 'Server error while fetching records.' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/eb-records/:id
// Deletes a single record by its MongoDB _id.
// ─────────────────────────────────────────────────────────────────────────────
exports.deleteRecord = async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ success: false, message: 'Invalid record ID format.' });
    }

    const record = await EbRecord.findByIdAndDelete(id);
    if (!record) {
      return res.status(404).json({ success: false, message: 'Record not found.' });
    }
    return res.status(200).json({ success: true, message: 'Record deleted successfully.' });
  } catch (error) {
    console.error('[deleteRecord]', error);
    return res.status(500).json({ success: false, message: 'Server error during deletion.' });
  }
};
