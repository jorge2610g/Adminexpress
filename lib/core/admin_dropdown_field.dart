import 'dart:math' as math;

import 'package:flutter/material.dart';

const Color _dropdownText = Color(0xFF0F172A);
const Color _dropdownHint = Color(0xFF98A2B3);
const Color _dropdownArrow = Color(0xFF475467);
const Color _dropdownCheck = Color(0xFF2563EB);

/// Selector de formulario que abre su lista justo debajo del campo.
///
/// Sustituye a [DropdownButtonFormField]: ese widget coloca la opción elegida
/// encima del campo y tapa el valor que se estaba viendo. Mantiene la misma forma
/// de uso (items, onChanged y decoration), así que el flujo no cambia.
class AdminDropdownField<T> extends StatefulWidget {
  const AdminDropdownField({
    super.key,
    required this.items,
    required this.onChanged,
    this.initialValue,
    this.value,
    this.decoration = const InputDecoration(),
    this.hint,
    this.dropdownColor,
    this.isExpanded = true,
  });

  /// Valor inicial. Si el padre cambia este valor, el campo se actualiza.
  final T? initialValue;

  /// Valor que muestra el campo cuando el padre lo controla.
  final T? value;

  final List<DropdownMenuItem<T>> items;

  /// Recibe la opción elegida. Si es null, el campo queda deshabilitado.
  final ValueChanged<T?>? onChanged;

  final InputDecoration decoration;

  /// Texto que se muestra mientras no hay una opción elegida.
  final Widget? hint;

  /// Fondo de la lista. Si no se indica, usa el del tema.
  final Color? dropdownColor;

  /// Se conserva por compatibilidad: el campo siempre ocupa el ancho de su contenedor.
  final bool isExpanded;

  @override
  State<AdminDropdownField<T>> createState() => _AdminDropdownFieldState<T>();
}

/// Envuelve cada opción para que también se pueda elegir la que tiene valor null.
class _Choice<T> {
  const _Choice(this.value);

  final T? value;
}

class _AdminDropdownFieldState<T> extends State<AdminDropdownField<T>> {
  late T? _selected = widget.value ?? widget.initialValue;

  @override
  void didUpdateWidget(covariant AdminDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value ||
        widget.initialValue != oldWidget.initialValue) {
      _selected = widget.value ?? widget.initialValue;
    }
  }

  DropdownMenuItem<T>? get _selectedItem {
    for (final item in widget.items) {
      if (item.value == _selected) return item;
    }
    return null;
  }

  Future<void> _open() async {
    // Sin opciones (por ejemplo, zona antes de elegir el país) no hay menú que mostrar.
    if (widget.items.isEmpty) return;
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    // La lista empieza justo debajo del campo, no sobre él.
    final buttonRect = Rect.fromPoints(
      button.localToGlobal(Offset(0, button.size.height), ancestor: overlay),
      button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    final width = button.size.width;
    final choice = await showMenu<_Choice<T>>(
      context: context,
      position: RelativeRect.fromRect(buttonRect, Offset.zero & overlay.size),
      color: widget.dropdownColor,
      constraints: BoxConstraints(
        minWidth: width,
        maxWidth: math.max(width, 280),
      ),
      items: [
        for (final item in widget.items)
          PopupMenuItem<_Choice<T>>(
            value: _Choice<T>(item.value),
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _dropdownText,
              ),
              child: Row(
                children: [
                  Expanded(child: item.child),
                  if (item.value == _selected)
                    const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: _dropdownCheck,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
    if (choice != null && mounted) {
      setState(() => _selected = choice.value);
      widget.onChanged?.call(choice.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    final selected = _selectedItem;
    final textColor =
        enabled && selected != null ? _dropdownText : _dropdownHint;

    return InkWell(
      onTap: enabled ? _open : null,
      mouseCursor:
          enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: widget.decoration.copyWith(
          enabled: enabled,
          suffixIcon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: enabled ? _dropdownArrow : _dropdownHint,
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 20,
          ),
        ),
        // Con texto de ayuda, la etiqueta sube para no tapar el texto de ayuda.
        isEmpty: selected == null && widget.hint == null,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: selected?.child ?? widget.hint ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
