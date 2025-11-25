const mongoose = require('mongoose');

const voltageMeasurementSchema = new mongoose.Schema({
  timeSinceStart: {
    type: Number,
    required: true
  },
  voltage: {
    type: Number,
    default: null
  }
}, { _id: false });

const ecgSchema = new mongoose.Schema({
  timestamp: {
    type: Date,
    required: true,
    index: true
  },
  classification: {
    type: Number,
    required: true,
    enum: [0, 1, 2, 3, 4, 5]  // Valid ECG classifications
    // 0: Not set
    // 1: Sinus rhythm
    // 2: Atrial fibrillation
    // 3: Inconclusive (low heart rate)
    // 4: Inconclusive (high heart rate)
    // 5: Inconclusive (poor reading)
  },
  averageHeartRate: {
    type: Number,
    default: null,
    min: 0,
    max: 300
  },
  samplingFrequency: {
    type: Number,
    default: null
  },
  voltageMeasurements: [voltageMeasurementSchema],
  symptomStatus: {
    type: Number,
    required: true
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
  timestamps: true
});

// Index for efficient querying
ecgSchema.index({ timestamp: -1, classification: 1 });

// Prevent duplicate entries
ecgSchema.index({ timestamp: 1 }, { unique: true });

const ECG = mongoose.model('AppleWatchECG', ecgSchema, 'AppleWatchECG');

module.exports = ECG;