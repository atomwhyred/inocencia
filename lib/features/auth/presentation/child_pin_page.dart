import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/responsive/max_content_width.dart';
import '../../../core/widgets/pin_verify_view.dart';
import '../../profiles/presentation/avatar_view.dart';
import '../application/session.dart';

/// PIN opcional del nino para entrar a su perfil.
class ChildPinPage extends ConsumerWidget {
  const ChildPinPage({super.key, required this.childId});

  final int childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref
        .watch(childProfilesProvider)
        .value
        ?.where((c) => c.id == childId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: MaxContentWidth(
          maxWidth: 520,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: child == null || !child.hasPin
                  ? const Text('Perfil no disponible')
                  : PinVerifyView(
                      title: '¡Hola, ${child.name}!',
                      subtitle: 'Escribe tu PIN secreto',
                      leading: AvatarView(avatar: child.avatar, radius: 48),
                      length: child.pinLength!,
                      lockoutScope: 'child_${child.id}',
                      verify: (pin) => ref
                          .read(childProfileRepositoryProvider)
                          .verifyPin(child.id, pin),
                      onSuccess: () {
                        ref.read(sessionProvider.notifier).selectChild(child.id);
                        context.go('/tutor');
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
