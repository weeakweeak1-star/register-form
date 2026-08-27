import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RechargeCardsScreen extends StatefulWidget {
  const RechargeCardsScreen({super.key});

  @override
  State<RechargeCardsScreen> createState() => _RechargeCardsScreenState();
}

class _RechargeCardsScreenState extends State<RechargeCardsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<dynamic> cards = [];
  bool isLoading = true;

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '-';
    try {
      final date = DateTime.parse(isoDate).toLocal();
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final amPm = date.hour >= 12 ? 'م' : 'ص';
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $hour:${date.minute.toString().padLeft(2, '0')} $amPm';
    } catch (e) {
      return isoDate;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchCards();
  }

  Future<void> _fetchCards() async {
    try {
      final response = await supabase
          .from('transactions')
          .select('*, profiles!driver_id(full_name)')
          .eq('type', 'deposit')
          .order('created_at', ascending: false);
      setState(() {
        cards = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سجل كروت الشحن', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : cards.isEmpty
                    ? const Center(child: Text('لا توجد بيانات'))
                    : DataTable(
                        columns: const [
                          DataColumn(label: Text('رقم العملية (مزود)')),
                          DataColumn(label: Text('المبلغ')),
                          DataColumn(label: Text('الحالة')),
                          DataColumn(label: Text('الكابتن')),
                          DataColumn(label: Text('تاريخ العملية')),
                        ],
                        rows: cards.map((card) {
                          return DataRow(cells: [
                            DataCell(Text(card['provider_tx_id']?.toString() ?? '-')),
                            DataCell(Text(card['amount'].toString())),
                            DataCell(Text(card['status'] ?? 'unknown')),
                            DataCell(Text(card['profiles']?['full_name'] ?? '-')),
                            DataCell(Text(_formatDate(card['created_at']))),
                          ]);
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }
}
