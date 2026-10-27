import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config.dart';
import '../state/providers.dart';
import '../widgets/illustration.dart';
import '../widgets/otp_boxes.dart';

const _resendSeconds = 30;
const _ink = Color(0xFF0B2E2B);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _otpSent = false;
  bool _busy = false;
  String? _error;
  String? _devCode;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Nomor lengkap (+62...) dari isian pengguna: awalan 0 atau 62 yang terlanjur diketik dibuang.
  String get _fullPhone {
    var d = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('62')) d = d.substring(2);
    if (d.startsWith('0')) d = d.substring(1);
    return '+62$d';
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown = _cooldown > 0 ? _cooldown - 1 : 0);
      if (_cooldown == 0) t.cancel();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendOtp() => _run(() async {
        final dev = await ref.read(authProvider.notifier).requestOtp(_fullPhone);
        setState(() {
          _otpSent = true;
          _devCode = dev;
          // Mode dev (tanpa SMS asli): kotak OTP terisi otomatis supaya tidak terlewat. SMS asli: kosong untuk diketik.
          _code.text = dev ?? '';
        });
        _startCooldown();
      });

  Future<void> _verify() => _run(() => ref.read(authProvider.notifier).verifyOtp(_fullPhone, _code.text.trim()));

  void _changeNumber() {
    _timer?.cancel();
    setState(() {
      _otpSent = false;
      _code.clear();
      _error = null;
      _devCode = null;
      _cooldown = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phoneReady = _phone.text.replaceAll(RegExp(r'\D'), '').length >= 8;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _LoginHero(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(_otpSent ? 'Verifikasi nomor' : 'Selamat datang!', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: _ink, letterSpacing: -.5, height: 1.1)),
                  const SizedBox(height: 8),
                  Text(
                    _otpSent ? 'Masukkan kode 6 digit yang dikirim ke $_fullPhone' : 'Masuk dengan nomor HP. Kami akan mengirim kode verifikasi sekali pakai.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: const Color(0xFF50706C), height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  if (!_otpSent)
                    TextField(
                      controller: _phone,
                      enabled: !_busy,
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(labelText: 'Nomor HP', hintText: '812 3456 7890', prefixText: '+62  ', prefixIcon: Icon(Icons.phone_iphone_rounded), filled: true, fillColor: Colors.white),
                    )
                  else ...[
                    OtpBoxes(controller: _code, enabled: !_busy, onChanged: (_) => setState(() {})),
                    if (_devCode != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFFFFF4DC), borderRadius: BorderRadius.circular(12)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.developer_mode_rounded, size: 18, color: Color(0xFFB26A00)),
                          const SizedBox(width: 8),
                          Flexible(child: Text('Mode dev: kode $_devCode', style: const TextStyle(color: Color(0xFF6B4A12), fontWeight: FontWeight.w600))),
                        ]),
                      ),
                    ],
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(14)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.error_outline_rounded, size: 20, color: theme.colorScheme.error),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, height: 1.3))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _busy ? null : (_otpSent ? (_code.text.length == 6 ? _verify : null) : (phoneReady ? _sendOtp : null)),
                    child: _busy
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : Text(_otpSent ? 'Masuk' : 'Kirim kode OTP'),
                  ),
                  if (_otpSent) ...[
                    const SizedBox(height: 6),
                    // Lebar penuh + teks dipotong: label "Kirim ulang kode (0:30)" tidak boleh meluap di layar sempit.
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(onPressed: (_busy || _cooldown > 0) ? null : _sendOtp, child: Text(resendLabel(_cooldown), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ),
                    TextButton(onPressed: _busy ? null : _changeNumber, child: const Text('Ganti nomor')),
                  ],
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Bagian atas layar login: latar teal melengkung, logo, nama merek, dan ilustrasi.
class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(24, top + 18, 24, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF14A398), Color(0xFF063B38)]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Column(children: [
        Row(children: [
          const Illustration('logo', width: 40, height: 40),
          const SizedBox(width: 12),
          Text(appName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: .3)),
        ]),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity, // selebar hero, supaya lingkaran dekoratif tidak terpotong jadi persegi
          height: 200,
          child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            Positioned(left: -30, top: 20, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .07)))),
            Positioned(right: -20, bottom: 0, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .06)))),
            const Illustration('onboarding_1', height: 200),
          ]),
        ),
      ]),
    );
  }
}
