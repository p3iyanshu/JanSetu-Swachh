import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _apiClient = ApiClient();
  late final AnimationController _flagController;
  bool _otpSent = false;
  bool _isLoading = false;
  String? _demoOtp;

  @override
  void initState() {
    super.initState();
    _flagController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _flagController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      _showMessage('Enter a valid phone number.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.dio.post(
        '/auth/request-otp',
        data: {'phone': phone},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final otp = data['demo_otp']?.toString() ?? '123456';
      _otpController.text = otp;
      setState(() {
        _otpSent = true;
        _demoOtp = otp;
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Demo OTP'),
            content: Text('Your demo OTP is $otp'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      _otpController.text = '123456';
      setState(() {
        _otpSent = true;
        _demoOtp = '123456';
      });
      _showMessage('Backend unavailable. Using demo fallback OTP 123456.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      _showMessage('Enter the OTP.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _apiClient.dio.post(
        '/auth/verify-otp',
        data: {'phone': phone, 'otp': otp},
      );
      // Fire-and-forget: don't block login on push-notification setup.
      NotificationService(_apiClient).registerForPhone(phone);
      if (mounted) {
        context.go('/report');
      }
    } on DioException catch (e) {
      _showMessage(e.response?.data?['detail']?.toString() ?? 'Invalid OTP.');
    } catch (_) {
      if (otp == '123456') {
        if (mounted) {
          context.go('/report');
        }
      } else {
        _showMessage('Could not verify OTP. Use 123456 for demo fallback.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _flagController,
            builder: (context, _) {
              return CustomPaint(
                painter: _IndianFlagBackgroundPainter(_flagController.value),
                child: const SizedBox.expand(),
              );
            },
          ),
          Container(color: Colors.white.withValues(alpha: 0.38)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'JanSetu',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixText: '+91 ',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.88),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (_otpSent) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 18),
                      decoration: InputDecoration(
                        labelText: 'OTP',
                        helperText: _demoOtp == null
                            ? null
                            : 'Demo OTP auto-filled: $_demoOtp',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.88),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLoading
                        ? null
                        : _otpSent
                            ? _verifyOtp
                            : _requestOtp,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _otpSent ? 'VERIFY OTP & LOGIN' : 'GET OTP',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/worker'),
                    child: const Text('Department Worker? Sign in here'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IndianFlagBackgroundPainter extends CustomPainter {
  final double progress;

  const _IndianFlagBackgroundPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final bandHeight = size.height / 3;
    final paints = [
      Paint()..color = const Color(0xFFFF9933).withValues(alpha: 0.92),
      Paint()..color = Colors.white.withValues(alpha: 0.96),
      Paint()..color = const Color(0xFF138808).withValues(alpha: 0.9),
    ];

    for (var index = 0; index < paints.length; index++) {
      final top = index * bandHeight;
      final path = Path()..moveTo(0, top);
      for (double x = 0; x <= size.width; x += 16) {
        final wave = math.sin(
          (x / size.width * math.pi * 2) +
              (progress * math.pi * 2) +
              index,
        );
        path.lineTo(x, top + 12 * wave);
      }
      path.lineTo(size.width, top + bandHeight);
      path.lineTo(0, top + bandHeight);
      path.close();
      canvas.drawPath(path, paints[index]);
    }

    final chakraPaint = Paint()
      ..color = const Color(0xFF000080).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = size.shortestSide * 0.18;
    canvas.drawCircle(center, radius, chakraPaint);
    for (var spoke = 0; spoke < 24; spoke++) {
      final angle = (math.pi * 2 / 24) * spoke + progress * math.pi * 2;
      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius,
        ),
        chakraPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_IndianFlagBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
