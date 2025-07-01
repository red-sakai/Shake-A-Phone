const mongoose = require('mongoose');

const medicalConditionSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  severity: {
    type: String,
    enum: ['Mild', 'Moderate', 'Severe'],
    default: 'Moderate'
  },
  details: {
    type: String,
    default: ''
  },
  medications: [{
    name: String,
    dosage: String,
    frequency: String
  }],
  emergencyInstructions: {
    type: String,
    default: ''
  }
});

const emergencyContactSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  relationship: {
    type: String,
    required: true,
    trim: true
  },
  phoneNumber: {
    type: String,
    required: true,
    trim: true
  },
  alternatePhone: {
    type: String,
    trim: true
  }
});

const medicalProfileSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    unique: true
  },
  fullName: {
    type: String,
    default: ''
  },
  dateOfBirth: {
    type: String,
    default: ''
  },
  gender: {
    type: String,
    default: 'Prefer not to say'
  },
  bloodType: {
    type: String,
    enum: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown'],
    default: 'Unknown'
  },
  studentId: {
    type: String,
    default: ''
  },
  allergies: [{
    type: String,
    trim: true
  }],
  conditions: [medicalConditionSchema],
  emergencyContacts: [emergencyContactSchema],
  medications: [{
    name: String,
    dosage: String,
    frequency: String,
    purpose: String
  }],
  specialInstructions: {
    type: String,
    default: ''
  },
  lastUpdated: {
    type: Date,
    default: Date.now
  }
});

const MedicalProfile = mongoose.model('MedicalProfile', medicalProfileSchema);

module.exports = MedicalProfile;
