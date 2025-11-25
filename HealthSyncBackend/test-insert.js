require('dotenv').config();
const mongoose = require('mongoose');
const ECG = require('./models/ECG');

console.log('Testing single document insert...\n');

async function testInsert() {
  try {
    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('✅ Connected to MongoDB');
    console.log(`📊 Database: ${mongoose.connection.name}\n`);
    
    // Create a simple test ECG document
    const testECG = {
      timestamp: new Date(),
      classification: 1,
      averageHeartRate: 75,
      samplingFrequency: 512,
      voltageMeasurements: [
        { timeSinceStart: 0.0, voltage: 0.00012 },
        { timeSinceStart: 0.002, voltage: 0.00015 }
      ],
      symptomStatus: 0,
      deviceInfo: {
        deviceModel: 'Test Device',
        osVersion: '1.0',
        appVersion: '1.0'
      }
    };
    
    console.log('Attempting to insert test ECG document...');
    
    // Try to save using .create() (simple insert)
    const result = await ECG.create(testECG);
    
    console.log('✅ SUCCESS! Document inserted:');
    console.log(`   ID: ${result._id}`);
    console.log(`   Timestamp: ${result.timestamp}`);
    console.log(`   Classification: ${result.classification}\n`);
    
    // Clean up - delete the test document
    await ECG.deleteOne({ _id: result._id });
    console.log('🧹 Test document cleaned up');
    
  } catch (error) {
    console.error('❌ ERROR:', error.message);
    console.error('\nFull error:', error);
  } finally {
    await mongoose.connection.close();
    console.log('\n🔌 Connection closed');
    process.exit(0);
  }
}

testInsert();