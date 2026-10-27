import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/max_content_width.dart';
import 'profile_form.dart';

/// Pagina a pantalla completa del formulario (telefono). En tablet se muestra
/// dentro del panel de administracion.
class ProfileEditPage extends StatelessWidget {
  const ProfileEditPage({super.key, this.childId});

  final int? childId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(childId == null ? 'Nuevo perfil' : 'Editar perfil'),
      ),
      body: SafeArea(
        child: MaxContentWidth(
          maxWidth: 560,
          child: ProfileForm(childId: childId, onDone: () => context.pop()),
        ),
      ),
    );
  }
}
