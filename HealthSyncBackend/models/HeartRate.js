const mongoose = require('mongoose');

const heartRateSchema = new mongoose.Schema({
  timestamp: {
    type: Date,
    required: true,
    index: true
  },
  heartRate: {
    type: Number,
    required: true,
    min: 0,
    max: 300  // Reasonable max for heart rate
  },
  sourceDevice: {
    type: String,
    required: true
  },
  metadataJSON: {
    type: String,
    default: null
  },
  // Device info from the sync
  deviceInfo: {
    deviceModel: String,
    osVersion: String,
    appVersion: String
  },
  // Sync metadata
  syncedAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true  // Adds createdAt and updatedAt
});

// Compound index for efficient querying
heartRateSchema.index({ timestamp: -1, sourceDevice: 1 });

// Prevent duplicate entries
heartRateSchema.index({ timestamp: 1, heartRate: 1, sourceDevice: 1 }, { unique: true });

const HeartRate = mongoose.model('AppleWatchHeartRate', heartRateSchema, 'AppleWatchHeartRate');

module.exports = HeartRate;