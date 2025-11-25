const express = require('express');
const router = express.Router();
const HeartRate = require('../models/HeartRate');
const ECG = require('../models/ECG');

// POST /api/health-data/heartrate - Sync heart rate data
router.post('/heartrate', async (req, res) => {
  try {
    const { data, deviceInfo } = req.body;
    
    if (!data || !Array.isArray(data)) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Data must be an array of heart rate samples'
      });
    }
    
    console.log(`Received ${data.length} heart rate samples`);
    
    // Prepare documents for bulk insert
    const documents = data.map(sample => ({
      timestamp: new Date(sample.timestamp),
      heartRate: sample.heartRate,
      sourceDevice: sample.sourceDevice,
      metadataJSON: sample.metadataJSON || null,
      deviceInfo: deviceInfo || {}
    }));
    
    // Use bulkWrite for better performance with duplicate handling
    const bulkOps = documents.map(doc => ({
      updateOne: {
        filter: {
          timestamp: doc.timestamp,
          heartRate: doc.heartRate,
          sourceDevice: doc.sourceDevice
        },
        update: { $setOnInsert: doc },
        upsert: true
      }
    }));
    
    const result = await HeartRate.bulkWrite(bulkOps, { ordered: false });
    
    console.log(`Inserted: ${result.upsertedCount}, Updated: ${result.modifiedCount}, Duplicates: ${data.length - result.upsertedCount}`);
    
    res.status(200).json({
      success: true,
      message: 'Heart rate data synced successfully',
      stats: {
        received: data.length,
        inserted: result.upsertedCount,
        updated: result.modifiedCount,
        duplicates: data.length - result.upsertedCount
      }
    });
    
  } catch (error) {
    console.error('Error syncing heart rate data:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to sync heart rate data',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// POST /api/health-data/ecg - Sync ECG data
router.post('/ecg', async (req, res) => {
  try {
    const { data, deviceInfo } = req.body;
    
    if (!data || !Array.isArray(data)) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Data must be an array of ECG recordings'
      });
    }
    
    console.log(`Received ${data.length} ECG recordings`);
    
    // Prepare documents for bulk insert
    const documents = data.map(sample => ({
      timestamp: new Date(sample.timestamp),
      classification: sample.classification,
      averageHeartRate: sample.averageHeartRate || null,
      samplingFrequency: sample.samplingFrequency || null,
      voltageMeasurements: sample.voltageMeasurements || [],
      symptomStatus: sample.symptomStatus,
      deviceInfo: deviceInfo || {}
    }));

    console.log("Here", documents);
    
    // Use bulkWrite for better performance with duplicate handling
    const bulkOps = documents.map(doc => ({
      updateOne: {
        filter: { timestamp: doc.timestamp },
        update: { $setOnInsert: doc },
        upsert: true
      }
    }));
    
    const result = await ECG.bulkWrite(bulkOps, { ordered: false });
    
    console.log(`Inserted: ${result.upsertedCount}, Updated: ${result.modifiedCount}, Duplicates: ${data.length - result.upsertedCount}`);
    
    res.status(200).json({
      success: true,
      message: 'ECG data synced successfully',
      stats: {
        received: data.length,
        inserted: result.upsertedCount,
        updated: result.modifiedCount,
        duplicates: data.length - result.upsertedCount
      }
    });
    
  } catch (error) {
    console.error('Error syncing ECG data:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to sync ECG data',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// GET /api/health-data/heartrate - Query heart rate data
router.get('/heartrate', async (req, res) => {
  try {
    const { startDate, endDate, limit = 100 } = req.query;
    
    const query = {};
    if (startDate || endDate) {
      query.timestamp = {};
      if (startDate) query.timestamp.$gte = new Date(startDate);
      if (endDate) query.timestamp.$lte = new Date(endDate);
    }
    
    const data = await HeartRate.find(query)
      .sort({ timestamp: -1 })
      .limit(parseInt(limit));
    
    res.status(200).json({
      success: true,
      count: data.length,
      data: data
    });
    
  } catch (error) {
    console.error('Error fetching heart rate data:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to fetch heart rate data'
    });
  }
});

// GET /api/health-data/ecg - Query ECG data
router.get('/ecg', async (req, res) => {
  try {
    const { startDate, endDate, limit = 20 } = req.query;
    
    const query = {};
    if (startDate || endDate) {
      query.timestamp = {};
      if (startDate) query.timestamp.$gte = new Date(startDate);
      if (endDate) query.timestamp.$lte = new Date(endDate);
    }
    
    const data = await ECG.find(query)
      .sort({ timestamp: -1 })
      .limit(parseInt(limit));
    
    res.status(200).json({
      success: true,
      count: data.length,
      data: data
    });
    
  } catch (error) {
    console.error('Error fetching ECG data:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to fetch ECG data'
    });
  }
});

// GET /api/health-data/stats - Get statistics
router.get('/stats', async (req, res) => {
  try {
    const [heartRateCount, ecgCount, latestHeartRate, latestECG] = await Promise.all([
      HeartRate.countDocuments(),
      ECG.countDocuments(),
      HeartRate.findOne().sort({ timestamp: -1 }),
      ECG.findOne().sort({ timestamp: -1 })
    ]);
    
    res.status(200).json({
      success: true,
      stats: {
        totalHeartRateSamples: heartRateCount,
        totalECGRecordings: ecgCount,
        latestHeartRateTimestamp: latestHeartRate?.timestamp,
        latestECGTimestamp: latestECG?.timestamp
      }
    });
    
  } catch (error) {
    console.error('Error fetching stats:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to fetch statistics'
    });
  }
});

module.exports = router;