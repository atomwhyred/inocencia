import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Teclado numerico con puntos de progreso. Llama a [onCompleted] al llegar a
/// [length] digitos. Cambia [resetToken] para borrar lo escrito (tras un error).
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.length,
    required this.onCompleted,
    this.resetToken = 0,
    this.enabled = true,
    this.errorText,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final int resetToken;
  final bool enabled;
  final String? errorText;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _digits = '';

  @override
  void didUpdateWidget(PinPad old) {
    super.didUpdateWidget(old);
    if (old.resetToken != widget.resetToken || old.length != widget.length) {
      _digits = '';
    }
  }

  void _add(String d) {
    if (!widget.enabled || _digits.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() => _digits += d);
    if (_digits.length == widget.length) widget.onCompleted(_digits);
  }

  void _back() {
    if (!widget.enabled || _digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.length; i++)
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _digits.length ? scheme.primary : Colors.transparent,
                    border: Border.all(color: scheme.primary, width: 2),
                  ),
                ),
            ],
          ),
          SizedBox(
            height: 28,
            child: widget.errorText == null
                ? null
                : Center(
                    child: Text(
                      widget.errorText!,
                      style: TextStyle(color: scheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [for (final d in row) _Key(label: d, onTap: () => _add(d))],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(width: 76, height: 64),
                _Key(label: '0', onTap: () => _add('0')),
                _Key(
                  icon: Icons.backspace_outlined,
                  semanticLabel: 'Borrar',
                  onTap: _back,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, this.semanticLabel, required this.onTap});

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 76,
      height: 64,
      child: Semantics(
        button: true,
        label: semanticLabel ?? label,
        child: Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Center(
              child: label != null
                  ? Text(
                      label!,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                    )
                  : Icon(icon, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}
