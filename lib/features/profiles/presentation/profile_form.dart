import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/constants.dart';
import '../../../core/di/providers.dart';
import '../../../core/utils/school_grade_calculator.dart';
import '../domain/child_profile.dart';
import 'avatar_view.dart';

/// Formulario para crear o editar un perfil infantil. Si [childId] es null,
/// crea uno nuevo.
class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({super.key, this.childId, required this.onDone});

  final int? childId;

  /// Se llama al guardar o eliminar con exito.
  final VoidCallback onDone;

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String _avatar = emojiAvatar(avatarEmojis.first);
  DateTime? _birthDate;
  int? _gradeOverride;
  bool _pinEnabled = false;
  int _pinLength = 4;
  bool _hadPin = false;
  bool _changingPin = false;

  /// Mensajes guardados de la conversacion de este nino con el tutor.
  int _messageCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.childId;
    if (id != null) {
      final c = await ref.read(childProfileRepositoryProvider).getById(id);
      if (c != null) {
        _nameController.text = c.name;
        _avatar = c.avatar;
        _birthDate = c.birthDate;
        _gradeOverride = c.gradeOverride;
        _hadPin = c.hasPin;
        _pinEnabled = c.hasPin;
        _pinLength = c.pinLength ?? 4;
        _messageCount = await ref.read(tutorHistoryRepositoryProvider).count(id);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickBirthDate() async {
    final now = ref.read(clockProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 8, now.month, now.day),
      firstDate: DateTime(now.year - 20),
      lastDate: now,
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _pickPhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked == null) return;
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'avatars'))..createSync(recursive: true);
      final dest = p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(picked.path).copy(dest);
      if (mounted) setState(() => _avatar = photoAvatar(dest));
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo cargar la foto.')),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige la fecha de nacimiento.')),
      );
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(childProfileRepositoryProvider);
    final input = ChildProfileInput(
      name: _nameController.text,
      avatar: _avatar,
      birthDate: _birthDate!,
      gradeOverride: _gradeOverride,
    );
    final newPin = _pinController.text;
    final id = widget.childId;
    if (id == null) {
      await repo.create(input, pin: _pinEnabled ? newPin : null);
    } else {
      final change = !_pinEnabled
          ? const RemoveChildPin()
          : (_hadPin && !_changingPin ? const KeepChildPin() : SetChildPin(newPin));
      await repo.update(id, input, change);
    }
    if (mounted) widget.onDone();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar perfil'),
        content: Text('¿Eliminar a ${_nameController.text}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(childProfileRepositoryProvider).delete(widget.childId!);
    if (mounted) widget.onDone();
  }

  Future<void> _clearConversations() async {
    final name = _nameController.text;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar conversaciones'),
        content: Text(
          '¿Borrar las conversaciones de $name con el tutor ($_messageCount mensajes)? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(tutorHistoryRepositoryProvider).clear(widget.childId!);
    if (!mounted) return;
    setState(() => _messageCount = 0);
    messenger.showSnackBar(const SnackBar(content: Text('Conversaciones borradas.')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final now = ref.read(clockProvider)();
    final autoGrade = _birthDate == null
        ? null
        : const SchoolGradeCalculator().gradeFor(_birthDate!, now: now);
    final dateText = _birthDate == null
        ? 'Elegir fecha'
        : DateFormat.yMMMMd('es').format(_birthDate!);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: AvatarView(avatar: _avatar, radius: 48)),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in avatarEmojis)
                ChoiceChip(
                  label: Text(e, style: const TextStyle(fontSize: 22)),
                  selected: _avatar == emojiAvatar(e),
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _avatar = emojiAvatar(e)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Usar una foto'),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Escribe el nombre' : null,
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
            leading: const Icon(Icons.cake_outlined),
            title: const Text('Fecha de nacimiento'),
            subtitle: Text(dateText),
            onTap: _pickBirthDate,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            initialValue: _gradeOverride,
            decoration: const InputDecoration(labelText: 'Grado escolar'),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(
                  autoGrade == null
                      ? 'Automático (según la edad)'
                      : 'Automático: ${SchoolGradeCalculator.label(autoGrade)}',
                ),
              ),
              for (var g = minSchoolGrade; g <= maxSchoolGrade; g++)
                DropdownMenuItem(value: g, child: Text(SchoolGradeCalculator.label(g))),
            ],
            onChanged: (v) => setState(() => _gradeOverride = v),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('PIN para el niño'),
            subtitle: const Text('Opcional: pide un PIN al abrir su perfil.'),
            value: _pinEnabled,
            onChanged: (v) => setState(() {
              _pinEnabled = v;
              _pinController.clear();
            }),
          ),
          if (_pinEnabled) ..._pinFields(),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(widget.childId == null ? 'Crear perfil' : 'Guardar cambios'),
          ),
          if (widget.childId != null) ...[
            const SizedBox(height: 24),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
              leading: const Icon(Icons.forum_outlined),
              title: const Text('Conversaciones con el tutor'),
              subtitle: Text(_messageCount == 0
                  ? 'No hay conversaciones guardadas.'
                  : _messageCount == 1
                      ? '1 mensaje guardado.'
                      : '$_messageCount mensajes guardados.'),
              trailing: TextButton(
                onPressed: _saving || _messageCount == 0 ? null : _clearConversations,
                child: const Text('Borrar'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Eliminar perfil'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _pinFields() {
    if (_hadPin && !_changingPin) {
      return [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _changingPin = true),
            icon: const Icon(Icons.password_rounded),
            label: const Text('Cambiar PIN'),
          ),
        ),
      ];
    }
    return [
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 4, label: Text('4 dígitos')),
          ButtonSegment(value: 6, label: Text('6 dígitos')),
        ],
        selected: {_pinLength},
        onSelectionChanged: (s) => setState(() {
          _pinLength = s.first;
          _pinController.clear();
        }),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _pinController,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: _pinLength,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(labelText: 'PIN del niño'),
        validator: (v) =>
            (v == null || v.length != _pinLength) ? 'Escribe $_pinLength dígitos' : null,
      ),
    ];
  }
}
