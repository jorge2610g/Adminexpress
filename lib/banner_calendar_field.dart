import 'package:flutter/material.dart';

class BannerCalendarField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  const BannerCalendarField(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Future<void> pick() async {
      final date = await showDatePicker(
          context: context,
          initialEntryMode: DatePickerEntryMode.calendarOnly,
          initialDate: value?.toLocal() ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          helpText: label,
          cancelText: 'Cancelar',
          confirmText: 'Elegir');
      if (date != null) onChanged(date);
    }

    final local = value?.toLocal();
    final display = local == null
        ? 'Seleccionar fecha'
        : '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    return InkWell(
      onTap: pick,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(children: [
          Expanded(child: Text(display)),
          if (value != null)
            IconButton(
                tooltip: 'Quitar fecha',
                onPressed: () => onChanged(null),
                icon: const Icon(Icons.close, size: 18)),
          IconButton(
              tooltip: 'Abrir calendario',
              onPressed: pick,
              icon: const Icon(Icons.calendar_month_outlined)),
        ]),
      ),
    );
  }
}
