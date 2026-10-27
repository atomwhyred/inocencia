import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/responsive/max_content_width.dart';
import '../../../core/widgets/pin_verify_view.dart';
import '../application/session.dart';

/// Pide el PIN del padre/madre para abrir el panel de administracion.
class ParentPinPage extends ConsumerWidget {
  const ParentPinPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guardian = ref.watch(guardianProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Zona de padres')),
      body: SafeArea(
        child: MaxContentWidth(
          maxWidth: 520,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: guardian == null
                  ? const CircularProgressIndicator()
                  : PinVerifyView(
                      title: 'Hola, ${guardian.name}',
                      subtitle: 'Introduce tu PIN',
                      leading: const Icon(Icons.lock_outline_rounded, size: 48),
                      length: guardian.pinLength,
                      lockoutScope: 'guardian',
                      verify: ref.read(guardianRepositoryProvider).verifyPin,
                      onSuccess: () {
                        ref.read(sessionProvider.notifier).unlockParent();
                        context.pushReplacement('/admin');
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
