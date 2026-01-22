import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _areaController = TextEditingController();
  
  String _userType = 'resident';

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);

    double? latitude;
    double? longitude;

    if (_userType == 'resident') {
      final position = await locationProvider.getCurrentLocation();
      if (position != null) {
        latitude = position.latitude;
        longitude = position.longitude;
      }
    }

    final success = await authProvider.register(
      phoneNumber: _phoneController.text,
      fullName: _nameController.text,
      userType: _userType,
      email: _emailController.text.isEmpty ? null : _emailController.text,
      area: _areaController.text.isEmpty ? null : _areaController.text,
      latitude: latitude,
      longitude: longitude,
    );

    if (!mounted) return;

    if (success) {
      if (authProvider.isResident) {
        Navigator.pushReplacementNamed(context, '/resident-home');
      } else {
        Navigator.pushReplacementNamed(context, '/collector-home');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Registration failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+256700123456',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (!RegExp(r'^\+256[0-9]{9}$').hasMatch(value)) {
                      return 'Format: +256XXXXXXXXX';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email (Optional)',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _areaController,
                  decoration: const InputDecoration(
                    labelText: 'Area/Division',
                    hintText: 'e.g., Nakawa, Kawempe',
                    prefixIcon: Icon(Icons.location_city),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('I am a:', style: TextStyle(fontWeight: FontWeight.bold)),
                RadioListTile<String>(
                  title: const Text('Resident'),
                  value: 'resident',
                  groupValue: _userType,
                  onChanged: (value) {
                    setState(() {
                      _userType = value!;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Garbage Collector'),
                  value: 'collector',
                  groupValue: _userType,
                  onChanged: (value) {
                    setState(() {
                      _userType = value!;
                    });
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: authProvider.isLoading ? null : _handleRegister,
                  child: authProvider.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
