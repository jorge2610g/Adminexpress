import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/core/driver_license_review_state.dart';

void main() {
  test('a verified legacy licence retains both approvals', () {
    final doc = <String, dynamic>{
      'status': 'verified',
      'front_object_path': 'driver/license/front.jpg',
      'back_object_path': 'driver/license/back.jpg',
      'review_parts': <String, dynamic>{},
    };
    expect(driverLicensePartStatus(doc, 'front'), 'approved');
    expect(driverLicensePartStatus(doc, 'back'), 'approved');
  });

  test('rejecting one side does not reject the other', () {
    final doc = <String, dynamic>{
      'status': 'rejected',
      'front_object_path': 'driver/license/front.jpg',
      'back_object_path': 'driver/license/back.jpg',
      'review_parts': {
        'front': {'status': 'approved', 'version': 1},
        'back': {'status': 'rejected', 'version': 2},
      },
    };
    expect(driverLicensePartStatus(doc, 'front'), 'approved');
    expect(driverLicensePartStatus(doc, 'back'), 'rejected');
  });

  test('missing photos cannot be approved', () {
    final doc = <String, dynamic>{
      'status': 'verified',
      'front_object_path': '',
      'back_object_path': 'driver/license/back.jpg',
    };
    expect(driverLicensePartStatus(doc, 'front'), 'pending');
    expect(driverLicensePartStatus(doc, 'back'), 'approved');
  });
}
