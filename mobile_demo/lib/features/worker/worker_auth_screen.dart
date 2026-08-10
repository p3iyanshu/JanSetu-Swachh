import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'worker_auth_provider.dart';

class WorkerAuthScreen extends ConsumerStatefulWidget {
  const WorkerAuthScreen({super.key});

  @override
  ConsumerState<WorkerAuthScreen> createState() => _WorkerAuthScreenState();
}

class _WorkerAuthScreenState extends ConsumerState<WorkerAuthScreen> {
  bool _isSignup = false;
  final _nameController = TextEditingController();
  final _empIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _contactController = TextEditingController();
  int? _selectedDepartmentId;

  @override
  void dispose() {
    _nameController.dispose();
    _empIdController.dispose();
    _passwordController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notifier = ref.read(workerAuthProvider.notifier);
    final empId = _empIdController.text.trim();
    final password = _passwordController.text.trim();

    if (empId.isEmpty || password.isEmpty) {
      _showMessage('Enter employee ID and password.');
      return;
    }

    bool success;
    if (_isSignup) {
      final name = _nameController.text.trim();
      if (name.isEmpty || _selectedDepartmentId == null) {
        _showMessage('Enter your name and select a department.');
        return;
      }
      success = await notifier.signup(
        name: name,
        empId: empId,
        departmentId: _selectedDepartmentId!,
        password: password,
        contact: _contactController.text.trim().isEmpty ? null : _contactController.text.trim(),
      );
    } else {
      success = await notifier.login(empId: empId, password: password);
    }

    if (success && mounted) {
      context.go('/worker/home');
    } else if (mounted) {
      final error = ref.read(workerAuthProvider).error;
      if (error != null) _showMessage(error);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(workerAuthProvider);
    final departmentsReady = authState.departments.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.engineering_outlined, size: 56, color: AppTheme.primaryColor),
              const SizedBox(height: 12),
              const Text(
                'JanSetu',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
              const Text(
                'Worker — Solid Waste Demo',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppTheme.accentOrange, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              _buildToggle(),
              const SizedBox(height: 20),
              if (_isSignup) ...[
                _buildDepartmentDropdown(authState),
                if (authState.departments.isEmpty && !authState.isLoadingDepartments) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Could not load departments. Check the backend is running.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.read(workerAuthProvider.notifier).loadDepartments(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                _buildField(_nameController, 'Employee Name'),
                const SizedBox(height: 12),
              ],
              _buildField(_empIdController, 'Employee ID'),
              const SizedBox(height: 12),
              _buildField(_passwordController, 'Password', obscure: true),
              if (_isSignup) ...[
                const SizedBox(height: 12),
                _buildField(_contactController, 'Contact Number (optional)', keyboardType: TextInputType.phone),
              ],
              if (authState.error != null) ...[
                const SizedBox(height: 12),
                Text(authState.error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: authState.isLoading || (_isSignup && !departmentsReady) ? null : _submit,
                child: authState.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(_isSignup ? 'REGISTER' : 'SIGN IN'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Back to Citizen App'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggle() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: !_isSignup ? AppTheme.accentBlue : Colors.transparent,
              foregroundColor: !_isSignup ? Colors.white : AppTheme.primaryColor,
            ),
            onPressed: () => setState(() => _isSignup = false),
            child: const Text('Sign In'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: _isSignup ? AppTheme.accentBlue : Colors.transparent,
              foregroundColor: _isSignup ? Colors.white : AppTheme.primaryColor,
            ),
            onPressed: () {
              setState(() => _isSignup = true);
              if (ref.read(workerAuthProvider).departments.isEmpty) {
                ref.read(workerAuthProvider.notifier).loadDepartments();
              }
            },
            child: const Text('First Signup'),
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentDropdown(WorkerAuthState authState) {
    return DropdownButtonFormField<int>(
      initialValue: _selectedDepartmentId,
      decoration: InputDecoration(
        labelText: authState.isLoadingDepartments ? 'Loading departments...' : 'Department',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: authState.departments
          .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
          .toList(),
      onChanged: authState.departments.isEmpty
          ? null
          : (value) => setState(() => _selectedDepartmentId = value),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
