import 'package:flutter/material.dart';
import '../services/medical_profile_service.dart';

class MedicalProfilePage extends StatefulWidget {
  const MedicalProfilePage({super.key});

  @override
  State<MedicalProfilePage> createState() => _MedicalProfilePageState();
}

class _MedicalProfilePageState extends State<MedicalProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isInitializing = true;
  
  // Form controllers
  final _bloodTypeController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _specialInstructionsController = TextEditingController();
  
  // Lists for more complex data
  List<Map<String, dynamic>> _conditions = [];
  List<Map<String, dynamic>> _emergencyContacts = [];
  List<Map<String, dynamic>> _medications = [];
  
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }
  
  Future<void> _loadProfile() async {
    setState(() {
      _isInitializing = true;
    });
    
    try {
      final result = await MedicalProfileService.getMedicalProfile();
      
      if (result['success'] && result['profile'] != null) {
        final profile = result['profile'];
        
        // Fill form controllers
        _bloodTypeController.text = profile['bloodType'] ?? '';
        _allergiesController.text = (profile['allergies'] as List?)?.join(', ') ?? '';
        _specialInstructionsController.text = profile['specialInstructions'] ?? '';
        
        // Parse complex data
        if (profile['conditions'] != null) {
          _conditions = List<Map<String, dynamic>>.from(profile['conditions']);
        }
        
        if (profile['emergencyContacts'] != null) {
          _emergencyContacts = List<Map<String, dynamic>>.from(profile['emergencyContacts']);
        }
        
        if (profile['medications'] != null) {
          _medications = List<Map<String, dynamic>>.from(profile['medications']);
        }
      }
    } catch (e) {
      // Handle error (show a snackbar, etc.)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e'))
      );
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }
  
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Parse allergies from comma-separated string to list
      final allergies = _allergiesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
      
      final result = await MedicalProfileService.updateMedicalProfile(
        bloodType: _bloodTypeController.text,
        allergies: allergies,
        conditions: _conditions,
        emergencyContacts: _emergencyContacts,
        medications: _medications,
        specialInstructions: _specialInstructionsController.text,
      );
      
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medical profile saved successfully'))
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${result['error']}'))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e'))
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Medical Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Profile'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            onPressed: _isLoading ? null : _saveProfile,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile form UI
            // ...
          ],
        ),
      ),
    );
  }
}
