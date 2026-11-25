String? validateBannerDraft(
    {required String title,
    required String link,
    required bool hasImage,
    required int seconds,
    DateTime? start,
    DateTime? end}) {
  if (title.trim().isEmpty) return 'El título interno es obligatorio.';
  if (!hasImage) return 'Sube una imagen para el banner.';
  final uri = Uri.tryParse(link.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    return 'Escribe la URL HTTPS de la promoción.';
  }
  if (seconds < 3 || seconds > 60)
    return 'La duración debe estar entre 3 y 60 segundos.';
  if (start != null && end != null && !end.isAfter(start)) {
    return 'La fecha de fin debe ser posterior a la de inicio.';
  }
  return null;
}
