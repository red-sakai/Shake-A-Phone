const express = require('express');
const cors = require('cors');
const http = require('http');
const socketIo = require('socket.io');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
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

// Send emergency alert
app.post('/api/emergency-alert', (req, res) => {
  try {
    const { location, studentName, alertType = 'emergency' } = req.body;
    
    if (!location || !location.latitude || !location.longitude) {
      return res.status(400).json({
        success: false,
        error: 'Location data is required'
      });
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
        name: studentName || 'Anonymous Student'
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
