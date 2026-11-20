import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../game/domain/net_sanitize.dart';

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

  /// Las miniaturas de red se decodifican una vez (se pintan en cada fotograma de la
  /// carrera). Como mucho unas pocas: en una sala hay 6 jugadores.
  static final _decoded = <String, Uint8List>{};
  static const _maxDecoded = 16;

  static Uint8List _bytesOf(String avatar) {
    final hit = _decoded.remove(avatar);
    if (hit != null) return _decoded[avatar] = hit; // al final: usado hace poco
    Uint8List bytes;
    try {
      bytes = avatar.length > NetSanitize.maxImageAvatarChars
          ? Uint8List(0)
          : base64Decode(avatar.substring(4));
    } catch (_) {
      bytes = Uint8List(0);
    }
    if (_decoded.length >= _maxDecoded) _decoded.remove(_decoded.keys.first);
    return _decoded[avatar] = bytes;
  }

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
      final bytes = _bytesOf(avatar);
      // Se decodifica al tamaño en pantalla: una imagen enorme comprimida en pocos KB
      // no llega a ocupar memoria a resolución completa.
      final px = (radius * 2 * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(16, 512);
      return CircleAvatar(
        radius: radius,
        backgroundColor: scheme.secondaryContainer,
        backgroundImage: bytes.isEmpty
            ? null
            : ResizeImage(MemoryImage(bytes), width: px, height: px, policy: ResizeImagePolicy.fit),
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
