require('dotenv').config();

// Simple API key authentication middleware
const authenticateApiKey = (req, res, next) => {
  const apiKey = req.headers['x-api-key'];
  
  if (!apiKey) {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'API key is required. Please include X-API-Key header.'
    });
  }
  
  if (apiKey !== process.env.API_KEY) {
    return res.status(403).json({
      error: 'Forbidden',
      message: 'Invalid API key'
    });
  }
  
  // API key is valid, proceed
  next();
};

module.exports = { authenticateApiKey };