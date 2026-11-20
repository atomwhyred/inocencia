import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/di/providers.dart';
import '../../../core/responsive/max_content_width.dart';
import '../../../core/widgets/offline_badge.dart';
import '../../../core/widgets/pin_pad.dart';
import '../../../core/security/pin_strength.dart';

enum _Step { name, pin, confirm }

/// Primer arranque: crea el perfil del padre/madre con su PIN.
class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  _Step _step = _Step.name;
  int _pinLength = 4;
  String? _firstPin;
  int _resetToken = 0;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _goToPin() {
    if (_formKey.currentState!.validate()) setState(() => _step = _Step.pin);
  }

  void _onFirstPin(String pin) {
    final weak = weakPinReason(pin);
    if (weak != null) {
      setState(() {
        _error = weak;
        _resetToken++;
      });
      return;
    }
    setState(() {
      _firstPin = pin;
      _step = _Step.confirm;
      _error = null;
      _resetToken++;
    });
  }

  Future<void> _onConfirmPin(String pin) async {
    if (pin != _firstPin) {
      setState(() {
        _error = 'Los PIN no coinciden. Prueba de nuevo.';
        _firstPin = null;
        _step = _Step.pin;
        _resetToken++;
      });
      return;
    }
    setState(() => _saving = true);
    // El router detecta al administrador creado y navega solo.
    await ref
        .read(guardianRepositoryProvider)
        .create(name: _nameController.text, pin: pin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(appName)),
      body: SafeArea(
        child: MaxContentWidth(
          maxWidth: 520,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: switch (_step) {
              _Step.name => _nameStep(context),
              _Step.pin => _pinStep(
                  context,
                  title: 'Crea tu PIN',
                  subtitle: 'Lo usarás para entrar al panel de padres.',
                  onCompleted: _onFirstPin,
                ),
              _Step.confirm => _pinStep(
                  context,
                  title: 'Repite tu PIN',
                  subtitle: 'Para asegurarnos de que lo recuerdas.',
                  onCompleted: _onConfirmPin,
                ),
            },
          ),
        ),
      ),
    );
  }

  Widget _nameStep(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            '¡Bienvenido a $appName!',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Center(child: OfflineBadge()),
          const SizedBox(height: 16),
          Text(
            'Primero configuremos la cuenta del padre o la madre. '
            'Desde ahí podrás crear los perfiles de tus hijos.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Tu nombre'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Escribe tu nombre' : null,
            onFieldSubmitted: (_) => _goToPin(),
          ),
          const SizedBox(height: 12),
          Text('Longitud del PIN', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 4, label: Text('4 dígitos')),
              ButtonSegment(value: 6, label: Text('6 dígitos')),
            ],
            selected: {_pinLength},
            onSelectionChanged: (s) => setState(() => _pinLength = s.first),
          ),
          const SizedBox(height: 28),
          FilledButton(onPressed: _goToPin, child: const Text('Continuar')),
        ],
      ),
    );
  }

  Widget _pinStep(
    BuildContext context, {
    required String title,
    required String subtitle,
    required ValueChanged<String> onCompleted,
  }) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        PinPad(
          length: _pinLength,
          resetToken: _resetToken,
          enabled: !_saving,
          errorText: _error,
          onCompleted: onCompleted,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _saving
              ? null
              : () => setState(() {
                    _step = _Step.name;
                    _firstPin = null;
                    _error = null;
                  }),
          child: const Text('Volver'),
        ),
      ],
    );
  }
}
