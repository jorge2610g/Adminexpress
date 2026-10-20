import 'package:flutter/material.dart';

// Piezas visuales compartidas del panel administrativo.
// Colores y medidas tomados de la referencia de diseño (docs/design/admin-mockup).

const Color adminUiInk = Color(0xFF0F172A);
const Color adminUiMuted = Color(0xFF64748B);
const Color adminUiLine = Color(0xFFE7ECF3);
const Color adminUiBlue = Color(0xFF2563EB);
const Color adminUiBlueSoft = Color(0xFFEAF2FF);
const Color adminUiBlueLine = Color(0xFFBFD3F9);

/// Color del estado según su valor técnico (completed, pending, cancelled...).
Color adminStatusColor(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'completed':
    case 'paid':
    case 'approved':
    case 'active':
    case 'online':
      return const Color(0xFF14804A);
    case 'in_progress':
    case 'on_the_way':
    case 'picked_up':
      return adminUiBlue;
    case 'accepted':
      return const Color(0xFF7C3AED);
    case 'pending':
    case 'searching':
    case 'waiting':
    case 'suspended':
      return const Color(0xFFB54708);
    case 'cancelled':
    case 'canceled':
    case 'rejected':
    case 'failed':
    case 'blocked':
      return const Color(0xFFD92D20);
    default:
      return const Color(0xFF98A2B3);
  }
}

/// Pastilla seleccionable para periodos, estados y categorías.
class AdminPillChoice extends StatelessWidget {
  const AdminPillChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.dotColor,
    this.showCheck = false,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final Color? dotColor;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? adminUiBlueSoft : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? adminUiBlueLine : const Color(0xFFE4E7EC),
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => onSelected(true),
        child: SizedBox(
          height: 32,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showCheck && selected) ...[
                  const Icon(Icons.check_rounded, size: 15, color: adminUiBlue),
                  const SizedBox(width: 6),
                ],
                if (dotColor != null) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? adminUiBlue : adminUiInk,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastilla de estado con punto de color, como en las tablas de la referencia.
class AdminStatusPill extends StatelessWidget {
  const AdminStatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dato con etiqueta pequeña encima del valor, en una columna de ancho fijo.
class AdminDetailCell extends StatelessWidget {
  const AdminDetailCell({
    super.key,
    required this.label,
    required this.value,
    this.width = 150,
  });

  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label.isNotEmpty) ...[
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: adminUiMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: adminUiInk,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuadro de icono redondeado (34 px por defecto), como en las filas de la referencia.
class AdminIconTile extends StatelessWidget {
  const AdminIconTile({
    super.key,
    required this.icon,
    this.size = 34,
    this.color = adminUiBlue,
    this.background = adminUiBlueSoft,
  });

  final IconData icon;
  final double size;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * .29),
      ),
      child: Icon(icon, color: color, size: size * .5),
    );
  }
}

/// Campo con su etiqueta encima, como en las fichas de la referencia.
class AdminFormField extends StatelessWidget {
  const AdminFormField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: adminUiMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}
