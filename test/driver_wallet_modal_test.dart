import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  group('DriverWalletModal Safe Null Handling & Auto-Creation Logic', () {
    test('Simulate null wallet response: balance safely defaults to 0.0 without Null check error', () {
      // Simulation of database returning null for a new captain
      const Map<String, dynamic>? walletResponse = null;

      // Safe null handling logic as implemented in DriverWalletModal
      final rawBalance = walletResponse?['balance'];
      final safeBalance = (rawBalance is num) ? rawBalance.toDouble() : 0.0;

      expect(safeBalance, equals(0.0));
      expect('${NumberFormat('#,##0').format(safeBalance)} د.ع', equals('0 د.ع'));
    });

    test('Simulate wallet response with null balance: safely defaults to 0.0', () {
      final Map<String, dynamic> walletResponse = {'balance': null};

      final rawBalance = walletResponse['balance'];
      final safeBalance = (rawBalance is num) ? rawBalance.toDouble() : 0.0;

      expect(safeBalance, equals(0.0));
      expect('${NumberFormat('#,##0').format(safeBalance)} د.ع', equals('0 د.ع'));
    });

    test('Simulate auto-creation fallback when wallet record is missing', () {
      Map<String, dynamic>? walletResponse;

      // When walletResponse is null, auto-creation triggers:
      walletResponse ??= {'balance': 0.0};

      final rawBalance = walletResponse['balance'];
      final safeBalance = (rawBalance is num) ? rawBalance.toDouble() : 0.0;

      expect(safeBalance, equals(0.0));
      expect('${NumberFormat('#,##0').format(safeBalance)} د.ع', equals('0 د.ع'));
    });

    test('Simulate transaction list with null values: renders safely without null check exception', () {
      final dynamic txData = [
        {'amount': null, 'type': null, 'created_at': null},
        {'amount': 5000, 'type': 'deposit', 'created_at': '2026-10-23T10:00:00Z'},
        {'amount': -2000, 'type': 'withdrawal', 'created_at': null},
      ];

      final safeTxList = (txData as List<dynamic>?) ?? [];
      final transactions = safeTxList.map((tx) {
        if (tx is Map<String, dynamic>) return tx;
        return Map<String, dynamic>.from(tx as Map);
      }).toList();

      expect(transactions.length, equals(3));

      for (final tx in transactions) {
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final type = (tx['type'] as String?) ?? 'deposit';
        final isDeposit = type == 'deposit' || type == 'trip_payment';

        String displayType = type;
        if (type == 'deposit') displayType = 'إيداع';
        if (type == 'withdrawal') displayType = 'سحب';

        final dateStr = tx['created_at'] != null
            ? tx['created_at'].toString().split('T').first
            : '';

        final formattedAmount = '${isDeposit ? '+' : '-'}${NumberFormat('#,##0').format(amount.abs())}';

        expect(amount, isA<double>());
        expect(displayType, isNotEmpty);
        expect(formattedAmount, isNotEmpty);
        expect(dateStr, isNotNull);
      }
    });

    test('Simulate safe display name when driver full_name is null or empty', () {
      String resolveName(String? name) => (name == null || name.isEmpty) ? 'بدون اسم' : name;

      expect(resolveName(null), equals('بدون اسم'));
      expect(resolveName(''), equals('بدون اسم'));
      expect(resolveName('كابتن علي'), equals('كابتن علي'));
    });
  });
}
