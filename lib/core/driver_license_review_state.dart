/// Returns the review state for one side of a driver's licence.
/// Older documents only had an overall status; preserve prior approvals
/// while a newer review_parts structure is introduced.
String driverLicensePartStatus(Map<String, dynamic> document, String slot) {
  if (slot != 'front' && slot != 'back') return 'pending';
  final rawPath = document[slot == 'front'
      ? 'front_object_path'
      : 'back_object_path']?.toString().trim() ?? '';
  if (rawPath.isEmpty) return 'pending';
  final rawParts = document['review_parts'];
  final parts = rawParts is Map ? rawParts : const <String, dynamic>{};
  final rawEntry = parts[slot];
  final entry = rawEntry is Map ? rawEntry : const <String, dynamic>{};
  final status = entry['status']?.toString().trim().toLowerCase() ?? '';
  if (status == 'approved' || status == 'pending' || status == 'rejected') {
    return status;
  }
  final legacy = document['status']?.toString().trim().toLowerCase() ?? '';
  return legacy == 'verified'
      ? 'approved'
      : legacy == 'rejected' ? 'rejected' : 'pending';
}
