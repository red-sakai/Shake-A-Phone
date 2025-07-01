const express = require('express');
const cors = require('cors');
const http = require('http');
const socketIo = require('socket.io');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const mongoose = require('mongoose');
const User = require('./models/user');
const MedicalProfile = require('./models/medical_profile');
require('dotenv').config();

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST", "PUT"]
  }
});

// Middleware
app.use(cors());
app.use(express.json());

// In-memory storage (replace with database in production)
const emergencyAlerts = [];
const adminUsers = new Map();
const connectedAdmins = new Map();

// Default admin credentials
const defaultAdmin = {
  id: 'admin-001',
  username: 'rhs_clinic',
  password: 'clinic2024', // In production, use hashed passwords
  name: 'RHS Clinic Admin',
  role: 'admin'
};

// Connect to MongoDB with better error handling and fallback
mongoose.connect('mongodb://localhost:27017/rhs_emergency', {
  useNewUrlParser: true,
  useUnifiedTopology: true
})
.then(() => {
  console.log('📊 MongoDB connected');
  global.useDatabase = true;
})
.catch(err => {
  console.error('MongoDB connection error:', err);
  console.log('\n🚨 WARNING: Running without database. Data will not persist!');
  console.log('📋 To install MongoDB:');
  console.log('   Windows: Download from mongodb.com');
  console.log('   Mac: Run "brew install mongodb-community"');
  console.log('   Linux: Run "sudo apt install mongodb"');
  
  global.useDatabase = false;
});

// Socket.io connection handling
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);
  
  socket.on('register-admin', (data) => {
    connectedAdmins.set(socket.id, data);
    console.log('Admin connected:', data.name);
    
    // Send recent alerts to newly connected admin
    const recentAlerts = emergencyAlerts
      .filter(alert => alert.status === 'active')
      .slice(-10);
    
    socket.emit('recent-alerts', recentAlerts);
  });
  
  socket.on('disconnect', () => {
    connectedAdmins.delete(socket.id);
    console.log('Client disconnected:', socket.id);
  });
});

// Serve static files for admin dashboard
app.use('/admin', express.static(path.join(__dirname, '../admin_dashboard')));

// Redirect root to admin dashboard
app.get('/', (req, res) => {
  res.redirect('/admin');
});

// API routes
app.get('/api', (req, res) => {
  res.json({ 
    message: 'RHS Emergency Alert System',
    status: 'active',
    timestamp: new Date().toISOString(),
    connectedAdmins: connectedAdmins.size
  });
});

// Create or update medical profile
app.post('/api/medical-profile', async (req, res) => {
  try {
    const { userId, bloodType, allergies, conditions, emergencyContacts, medications, specialInstructions } = req.body;
    
    // Find existing profile or create new one
    let profile = await MedicalProfile.findOne({ userId });
    
    if (profile) {
      // Update existing profile
      profile.bloodType = bloodType || profile.bloodType;
      profile.allergies = allergies || profile.allergies;
      profile.conditions = conditions || profile.conditions;
      profile.emergencyContacts = emergencyContacts || profile.emergencyContacts;
      profile.medications = medications || profile.medications;
      profile.specialInstructions = specialInstructions || profile.specialInstructions;
      profile.lastUpdated = Date.now();
      
      await profile.save();
    } else {
      // Create new profile
      profile = new MedicalProfile({
        userId,
        bloodType,
        allergies,
        conditions,
        emergencyContacts,
        medications,
        specialInstructions
      });
      
      await profile.save();
    }
    
    res.status(200).json({
      success: true,
      message: 'Medical profile updated successfully',
      profile
    });
    
  } catch (error) {
    console.error('Error updating medical profile:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update medical profile',
      error: error.message
    });
  }
});

// Get medical profile by user ID
app.get('/api/medical-profile/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    const profile = await MedicalProfile.findOne({ userId }).populate('userId', 'username name');
    
    if (!profile) {
      return res.status(404).json({
        success: false,
        message: 'Medical profile not found'
      });
    }
    
    res.json({
      success: true,
      profile
    });
    
  } catch (error) {
    console.error('Error fetching medical profile:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch medical profile',
      error: error.message
    });
  }
});

// Send emergency alert
app.post('/api/emergency-alert', async (req, res) => {
  try {
    const { location, studentName, userId, alertType = 'emergency' } = req.body;
    
    if (!location || !location.latitude || !location.longitude) {
      return res.status(400).json({
        success: false,
        error: 'Location data is required'
      });
    }
    
    // Fetch medical profile if userId is provided
    let medicalData = null;
    if (userId) {
      try {
        const profile = await MedicalProfile.findOne({ userId });
        if (profile) {
          medicalData = {
            bloodType: profile.bloodType,
            allergies: profile.allergies,
            conditions: profile.conditions.map(c => ({
              name: c.name,
              severity: c.severity,
              emergencyInstructions: c.emergencyInstructions
            })),
            emergencyContacts: profile.emergencyContacts
          };
        }
      } catch (err) {
        console.warn('Could not fetch medical profile:', err);
      }
    }
    
    const alert = {
      id: uuidv4(),
      timestamp: new Date().toISOString(),
      location: {
        latitude: location.latitude,
        longitude: location.longitude,
        accuracy: location.accuracy || 0,
        altitude: location.altitude,
        speed: location.speed,
        heading: location.heading
      },
      studentInfo: {
        name: studentName || 'Anonymous Student',
        userId: userId || null,
        medicalProfile: medicalData
      },
      alertType,
      status: 'active',
      responseTime: null,
      respondedBy: null
    };
    
    emergencyAlerts.push(alert);
    
    // Broadcast to all connected admins
    io.emit('emergency-alert', alert);
    
    console.log(`Emergency alert received: ${alert.id} from ${studentName || 'Anonymous'} at ${alert.location.latitude}, ${alert.location.longitude}`);
    console.log(`Alert type: ${alertType}`);
    
    res.status(201).json({
      success: true,
      alertId: alert.id,
      message: 'Emergency alert sent successfully',
      timestamp: alert.timestamp
    });
    
  } catch (error) {
    console.error('Error processing emergency alert:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to process emergency alert'
    });
  }
});

// Add this additional endpoint for compatibility with different mobile app implementations
app.post('/api/alerts/create', (req, res) => {
  // Forward to the main emergency alert endpoint
  app.handle(req, res, req.url = '/api/emergency-alert');
});

// Get all alerts (for admin dashboard)
app.get('/api/alerts', (req, res) => {
  try {
    const { status, limit = 50 } = req.query;
    
    let filteredAlerts = emergencyAlerts;
    
    if (status) {
      filteredAlerts = emergencyAlerts.filter(alert => alert.status === status);
    }
    
    const alerts = filteredAlerts
      .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))
      .slice(0, parseInt(limit));
    
    res.json({
      success: true,
      alerts,
      total: filteredAlerts.length,
      activeAlerts: emergencyAlerts.filter(a => a.status === 'active').length
    });
    
  } catch (error) {
    console.error('Error fetching alerts:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch alerts'
    });
  }
});

// Update alert status (admin response)
app.put('/api/alerts/:alertId/respond', (req, res) => {
  try {
    const { alertId } = req.params;
    const { status, respondedBy } = req.body;
    
    const alertIndex = emergencyAlerts.findIndex(alert => alert.id === alertId);
    
    if (alertIndex === -1) {
      return res.status(404).json({
        success: false,
        message: 'Alert not found'
      });
    }
    
    emergencyAlerts[alertIndex] = {
      ...emergencyAlerts[alertIndex],
      status: status || 'responded',
      responseTime: new Date().toISOString(),
      respondedBy: respondedBy || 'Unknown Admin'
    };
    
    // Notify all admins about the response
    io.emit('alert-response', emergencyAlerts[alertIndex]);
    
    res.json({
      success: true,
      message: 'Alert response recorded',
      alert: emergencyAlerts[alertIndex]
    });
    
  } catch (error) {
    console.error('Error updating alert:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update alert'
    });
  }
});

// Admin login
app.post('/api/admin/login', (req, res) => {
  try {
    const { username, password } = req.body;
    
    if (username === defaultAdmin.username && password === defaultAdmin.password) {
      res.json({
        success: true,
        admin: {
          id: defaultAdmin.id,
          name: defaultAdmin.name,
          role: defaultAdmin.role
        },
        token: 'admin-token-' + Date.now() // Simple token for demo
      });
    } else {
      res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Login error'
    });
  }
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    connectedAdmins: connectedAdmins.size,
    totalAlerts: emergencyAlerts.length,
    activeAlerts: emergencyAlerts.filter(alert => alert.status === 'active').length
  });
});

// Add user registration endpoint
app.post('/api/register', async (req, res) => {
  try {
    const { username, password, name, email } = req.body;
    
    console.log(`Registration attempt for user: ${username}`);
    
    // Check if user already exists
    let existingUser;
    
    try {
      existingUser = await User.findOne({ username });
    } catch (dbErr) {
      console.error('Database error when checking existing user:', dbErr);
      // Continue with in-memory check if DB isn't available
    }
    
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Username already exists'
      });
    }
    
    // Create new user
    try {
      const user = new User({
        username,
        password, // Will be hashed by the pre-save hook in the model
        name: name || username,
        email: email || '',
      });
      
      await user.save();
      
      console.log(`User registered successfully: ${username}`);
      
      res.status(201).json({
        success: true,
        message: 'User registered successfully'
      });
    } catch (saveErr) {
      console.error('Error saving user to database:', saveErr);
      throw saveErr;
    }
  } catch (error) {
    console.error('Registration failed:', error);
    res.status(500).json({
      success: false,
      message: 'Registration failed',
      error: error.message
    });
  }
});

// Update login endpoint with better error handling
app.post('/api/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    
    console.log(`Login attempt for user: ${username}`);
    
    // Find user
    let user;
    try {
      user = await User.findOne({ username });
    } catch (dbErr) {
      console.error('Database error when finding user:', dbErr);
      // If DB isn't available, check if it's a default user
      if (username === defaultAdmin.username && password === defaultAdmin.password) {
        return res.json({
          success: true,
          user: {
            id: defaultAdmin.id,
            username: defaultAdmin.username,
            name: defaultAdmin.name,
            role: defaultAdmin.role
          },
          token: 'admin-token-' + Date.now()
        });
      }
      
      return res.status(500).json({
        success: false,
        message: 'Database error during login'
      });
    }
    
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }
    
    // Check password
    let isMatch = false;
    try {
      isMatch = await user.comparePassword(password);
    } catch (pwErr) {
      console.error('Password comparison error:', pwErr);
      return res.status(500).json({
        success: false,
        message: 'Error verifying password'
      });
    }
    
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }
    
    // Update last login
    user.lastLogin = Date.now();
    await user.save();
    
    console.log(`User logged in successfully: ${username}`);
    
    res.json({
      success: true,
      user: {
        id: user._id,
        username: user.username,
        name: user.name,
        role: user.role
      },
      token: 'user-token-' + Date.now() // Simple token for demo
    });
    
  } catch (error) {
    console.error('Login failed:', error);
    res.status(500).json({
      success: false,
      message: 'Login failed',
      error: error.message
    });
  }
});

// Add an admin API route to view users and profiles
app.get('/api/admin/users', async (req, res) => {
  // Simple API key check - replace with proper authentication in production
  const apiKey = req.headers['x-api-key'];
  if (apiKey !== 'admin-secret-key') {
    return res.status(401).json({ success: false, message: 'Unauthorized' });
  }

  try {
    const users = await User.find().select('-password'); // Exclude passwords
    res.json({ success: true, users });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/admin/medical-profiles', async (req, res) => {
  // Simple API key check - replace with proper authentication in production
  const apiKey = req.headers['x-api-key'];
  if (apiKey !== 'admin-secret-key') {
    return res.status(401).json({ success: false, message: 'Unauthorized' });
  }

  try {
    const profiles = await MedicalProfile.find();
    res.json({ success: true, profiles });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

const PORT = process.env.PORT || 3000;

server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚨 RHS Emergency Alert Backend running on port ${PORT}`);
  console.log(`📱 Mobile URL: http://YOUR_IP_ADDRESS:${PORT}`);
  console.log(`💻 Local URL: http://localhost:${PORT}`);
  console.log(`👨‍⚕️ Admin Login: rhs_clinic / clinic2024`);
  console.log(`\n📋 To find your IP address:`);
  console.log(`   Windows: ipconfig`);
  console.log(`   Mac/Linux: ifconfig`);
});
