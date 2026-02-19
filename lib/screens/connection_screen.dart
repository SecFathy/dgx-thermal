import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart' as cp;
import 'thermal_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '22');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect(cp.ConnectionProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    await provider.connect(
      host: _hostCtrl.text.trim(),
      username: _userCtrl.text.trim(),
      password: _passCtrl.text,
      port: int.tryParse(_portCtrl.text.trim()) ?? 22,
    );

    if (provider.state == cp.ConnectionState.connected && mounted) {
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (_) => const ThermalScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Consumer<cp.ConnectionProvider>(
          builder: (ctx, provider, _) {
            final isConnecting = provider.state == cp.ConnectionState.connecting;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 60),
                    _Logo(),
                    const SizedBox(height: 48),
                    _SectionLabel('HOST'),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        flex: 3,
                        child: _Field(
                          controller: _hostCtrl,
                          hint: 'IP Address or Hostname',
                          icon: Icons.dns_outlined,
                          keyboard: TextInputType.url,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 80,
                        child: _Field(
                          controller: _portCtrl,
                          hint: 'Port',
                          icon: Icons.lan_outlined,
                          keyboard: TextInputType.number,
                          validator: (v) {
                            final p = int.tryParse(v ?? '');
                            return (p == null || p < 1 || p > 65535)
                                ? 'Invalid'
                                : null;
                          },
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _SectionLabel('CREDENTIALS'),
                    const SizedBox(height: 8),
                    _Field(
                      controller: _userCtrl,
                      hint: 'Username',
                      icon: Icons.person_outline,
                      keyboard: TextInputType.text,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      controller: _passCtrl,
                      hint: 'Password',
                      icon: Icons.lock_outline,
                      keyboard: TextInputType.visiblePassword,
                      obscure: _obscurePass,
                      suffix: GestureDetector(
                        onTap: () =>
                            setState(() => _obscurePass = !_obscurePass),
                        child: Icon(
                          _obscurePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.white38,
                          size: 18,
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 32),
                    if (provider.state == cp.ConnectionState.error) ...[
                      _ErrorBanner(message: provider.errorMessage),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isConnecting ? null : () => _connect(provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A84FF),
                          disabledBackgroundColor: const Color(0xFF0A84FF).withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isConnecting
                            ? const CupertinoActivityIndicator(color: Colors.white)
                            : const Text(
                                'Connect via SSH',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF30D158).withValues(alpha: 0.4)),
          ),
          child: const Icon(Icons.device_thermostat, color: Color(0xFF30D158), size: 28),
        ),
        const SizedBox(height: 20),
        const Text(
          'DGX Thermal',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'SSH Thermal Monitor',
          style: TextStyle(fontSize: 15, color: Colors.white38),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.white38,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboard;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.keyboard,
    this.obscure = false,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      keyboardAppearance: Brightness.dark,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 15),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF1C1C1E),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0A84FF), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF3B30)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFF3B30), fontSize: 11),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF3B30), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
