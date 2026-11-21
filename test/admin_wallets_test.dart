import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/admin_wallets_helpers.dart';

void main() {
  test('importes: CLP sin decimales, el resto con dos', () {
    expect(adminWalletMoney(12.5, 'BOB'), 'BOB 12.50');
    expect(adminWalletMoney(1500, 'CLP'), 'CLP 1500');
    expect(adminWalletMoney(null, 'BOB'), 'BOB 0.00');
  });

  test('neto a liquidar según el saldo', () {
    expect(adminWalletSettleText(50, 'BOB'), 'Express debe pagarle BOB 50.00');
    expect(adminWalletSettleText(-8, 'BOB'), 'Debe a Express BOB 8.00');
    expect(adminWalletSettleText(0, 'BOB'), 'Al día: no hay nada que liquidar');
  });

  test('CSV de billeteras con BOM, encabezados y fórmulas neutralizadas', () {
    final csv = adminWalletsCsv([
      {
        'full_name': '=cmd',
        'role': 'driver',
        'email': 'a@b.c',
        'phone': '+591',
        'balance': 10,
        'currency_code': 'BOB',
        'tx_count': 2,
        'pending_withdrawals': 1,
        'last_activity': null,
      },
    ]);
    expect(csv.startsWith('﻿Nombre;Rol;'), isTrue);
    expect(csv, contains("'=cmd;Conductor;a@b.c;'+591;10;BOB;2;1;"));
  });
}
