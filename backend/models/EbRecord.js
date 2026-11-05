/**
 * EbRecord Mongoose Model
 * Stores EB consumer service location records with GeoJSON coordinates.
 * Includes scheduling fields for wiremen to plan house visits.
 */

const mongoose = require('mongoose');

const ebRecordSchema = new mongoose.Schema(
  {
    // EB Consumer / Service Number — must be unique per consumer
    ebNumber: {
      type: String,
      required: [true, 'EB Number is required'],
      trim: true,
      index: true,
    },

    // Optional human-readable consumer name
    consumerName: {
      type: String,
      trim: true,
      default: '',
    },

    // Optional consumer mobile number
    mobileNumber: {
      type: String,
      trim: true,
      default: '',
    },

    // Free-text landmark or notes (e.g., "Near blue gate, second left")
    landmarkNotes: {
      type: String,
      trim: true,
      default: '',
    },

    // GeoJSON Point: coordinates stored as [longitude, latitude]
    location: {
      type: {
        type: String,
        enum: ['Point'],
        default: 'Point',
      },
      coordinates: {
        type: [Number], // [lng, lat]
        required: [true, 'Coordinates [longitude, latitude] are required'],
        validate: {
          validator: (arr) =>
            Array.isArray(arr) &&
            arr.length === 2 &&
            arr[0] >= -180 && arr[0] <= 180 && // longitude
            arr[1] >= -90  && arr[1] <= 90,    // latitude
          message: 'Invalid coordinates. Must be [longitude, latitude].',
        },
      },
    },

    // Optional reverse-geocoded address string
    address: {
      type: String,
      trim: true,
      default: '',
    },

    // Scheduled visit date for the house (e.g. Today, Tomorrow, or specific day)
    scheduledDate: {
      type: Date,
      default: null,
      index: true,
    },

    // Visit status
    visitStatus: {
      type: String,
      enum: ['Pending', 'Completed', 'Cancelled'],
      default: 'Pending',
    },
  },
  {
    timestamps: true,
  }
);

// 2dsphere index enables MongoDB geospatial queries
ebRecordSchema.index({ location: '2dsphere' });

// Compound text index for fast search
ebRecordSchema.index(
  { ebNumber: 'text', consumerName: 'text', mobileNumber: 'text', landmarkNotes: 'text', address: 'text' },
  { name: 'eb_text_search' }
);

module.exports = mongoose.model('EbRecord', ebRecordSchema);
