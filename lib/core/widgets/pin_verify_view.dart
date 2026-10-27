import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';
import 'pin_pad.dart';

/// Pide un PIN, lo valida y aplica el bloqueo temporal tras fallos repetidos.
class PinVerifyView extends ConsumerStatefulWidget {
  const PinVerifyView({
    super.key,
    required this.title,
    required this.length,
    required this.verify,
    required this.lockoutScope,
    required this.onSuccess,
    this.subtitle,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final int length;
  final Future<bool> Function(String pin) verify;

  /// Clave del contador de fallos (p. ej. `guardian` o `child_3`).
  final String lockoutScope;
  final VoidCallback onSuccess;

  @override
  ConsumerState<PinVerifyView> createState() => _PinVerifyViewState();
}

class _PinVerifyViewState extends ConsumerState<PinVerifyView> {
  int _resetToken = 0;
  bool _busy = false;
  String? _error;
  Duration? _locked;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _refreshLock();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _refreshLock() {
    final now = ref.read(clockProvider)();
    final left = ref.read(pinLockoutProvider(widget.lockoutScope)).remaining(now);
    setState(() => _locked = left);
    _ticker?.cancel();
    if (left != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final l = ref
            .read(pinLockoutProvider(widget.lockoutScope))
            .remaining(ref.read(clockProvider)());
        setState(() => _locked = l);
        if (l == null) _ticker?.cancel();
      });
    }
  }

  Future<void> _onCompleted(String pin) async {
    if (_busy || _locked != null) return;
    setState(() => _busy = true);
    final lockout = ref.read(pinLockoutProvider(widget.lockoutScope));
    final ok = await widget.verify(pin);
    if (!mounted) return;
    if (ok) {
      await lockout.reset();
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onSuccess();
      return;
    }
    await lockout.registerFailure(ref.read(clockProvider)());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = 'PIN incorrecto';
      _resetToken++;
    });
    _refreshLock();
  }

  String _lockText(Duration d) {
    final s = d.inSeconds + 1;
    return s >= 60
        ? 'Demasiados intentos. Espera ${s ~/ 60} min ${s % 60} s.'
        : 'Demasiados intentos. Espera $s s.';
  }

  @override
  Widget build(BuildContext context) {
    final locked = _locked;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.leading != null) ...[widget.leading!, const SizedBox(height: 12)],
        Text(
          widget.title,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 4),
          Text(widget.subtitle!, textAlign: TextAlign.center),
        ],
        const SizedBox(height: 20),
        PinPad(
          length: widget.length,
          resetToken: _resetToken,
          enabled: !_busy && locked == null,
          errorText: locked != null ? _lockText(locked) : _error,
          onCompleted: _onCompleted,
        ),
      ],
    );
  }
}
