require('dotenv').config();
const mongoose = require('mongoose');

console.log('Testing MongoDB connection...\n');

mongoose.connect(process.env.MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true
})
.then(() => {
  console.log('✅ Successfully connected to MongoDB!');
  console.log(`📊 Database: ${mongoose.connection.name}`);
  console.log(`🔗 Host: ${mongoose.connection.host}`);
  
  mongoose.connection.close();
  process.exit(0);
})
.catch(err => {
  console.error('❌ MongoDB connection failed:');
  console.error(err.message);
  process.exit(1);
});