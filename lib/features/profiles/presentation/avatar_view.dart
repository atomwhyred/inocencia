import 'dart:io';

import 'package:flutter/material.dart';

/// Avatares predefinidos que el nino puede elegir sin foto.
const avatarEmojis = [
  '🦊', '🐼', '🦁', '🐯', '🐸', '🐵', '🐶', '🐱',
  '🦄', '🐙', '🐢', '🦉', '🐰', '🐨', '🐧', '🦋',
];

String emojiAvatar(String emoji) => 'emoji:$emoji';
String photoAvatar(String path) => 'photo:$path';

/// Muestra un avatar (`emoji:` o `photo:`) en un circulo.
class AvatarView extends StatelessWidget {
  const AvatarView({super.key, required this.avatar, this.radius = 32});

  final String avatar;
  final double radius;

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
    final emoji = avatar.startsWith('emoji:') ? avatar.substring(6) : '🙂';
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.secondaryContainer,
      child: Text(emoji, style: TextStyle(fontSize: radius * 1.1)),
    );
  }
}
