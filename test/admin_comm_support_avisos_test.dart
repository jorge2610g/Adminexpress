import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/admin_comm_support_avisos.dart';

void main() {
  final sql = File(
    'supabase/migrations/20261124150000_support_tickets_and_announcements.sql',
  ).readAsStringSync();

  test('cada RPC que llama el panel existe en la migración', () {
    for (final name in [
      AdminCommRpc.tickets,
      AdminCommRpc.ticketMessages,
      AdminCommRpc.ticketReply,
      AdminCommRpc.ticketClose,
      AdminCommRpc.ticketReopen,
      AdminCommRpc.announcementSave,
      AdminCommRpc.announcementList,
      AdminCommRpc.announcementSetStatus,
      AdminCommRpc.announcementDelete,
      AdminCommRpc.sendPush,
    ]) {
      expect(
        sql.contains('function public.$name('),
        isTrue,
        reason: name,
      );
    }
  });

  test('las categorías del panel coinciden con la restricción de la tabla', () {
    for (final key in AdminCommRpc.announcementCategories.keys) {
      expect(sql.contains("'$key'"), isTrue, reason: key);
    }
  });

  test('el texto de la push se acorta a 140 y el título a 90', () {
    expect(AdminCommRpc.pushBodyFrom('  hola \n  mundo '), 'hola mundo');
    final long = 'a' * 300;
    expect(AdminCommRpc.pushBodyFrom(long).length, 140);
    expect(AdminCommRpc.pushTitleFrom('b' * 200).length, 90);
  });
}
