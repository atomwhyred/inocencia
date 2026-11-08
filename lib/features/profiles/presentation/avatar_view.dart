import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Avatares predefinidos que el nino puede elegir sin foto.
const avatarEmojis = [
  '🦊', '🐼', '🦁', '🐯', '🐸', '🐵', '🐶', '🐱',
  '🦄', '🐙', '🐢', '🦉', '🐰', '🐨', '🐧', '🦋',
];

String emojiAvatar(String emoji) => 'emoji:$emoji';
String photoAvatar(String path) => 'photo:$path';

/// Miniatura de foto que llega por la red en el juego (`img:<png en base64>`).
String imageAvatar(Uint8List png) => 'img:${base64Encode(png)}';

/// Muestra un avatar (`emoji:`, `photo:` o `img:`) en un circulo.
class AvatarView extends StatelessWidget {
  const AvatarView({super.key, required this.avatar, this.radius = 32});

  final String avatar;
  final double radius;

  /// Las miniaturas de red se decodifican una vez (se pintan en cada fotograma de la carrera).
  static final _decoded = <String, Uint8List>{};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (avatar.startsWith('photo:')) {
      final file = File(avatar.substring(6));
      return CircleAvatar(
        radius: radius,
        backgroundColor: scheme.secondaryContainer,
        backgroundImage: file.existsSync() ? FileImage(file) : null,
        child: file.existsSync() ? null : Icon(Icons.person, size: radius),
      );
    }
    if (avatar.startsWith('img:')) {
      final bytes = _decoded.putIfAbsent(avatar, () {
        try {
          return base64Decode(avatar.substring(4));
        } catch (_) {
          return Uint8List(0);
        }
      });
      return CircleAvatar(
        radius: radius,
        backgroundColor: scheme.secondaryContainer,
        backgroundImage: bytes.isEmpty ? null : MemoryImage(bytes),
        child: bytes.isEmpty ? Icon(Icons.person, size: radius) : null,
      );
    }
    final emoji = avatar.startsWith('emoji:') ? avatar.substring(6) : '🙂';
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.secondaryContainer,
      child: Text(emoji, style: TextStyle(fontSize: radius * 1.1)),
    );
  }
}
