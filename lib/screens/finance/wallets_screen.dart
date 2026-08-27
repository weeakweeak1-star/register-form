import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  String searchQuery = '';
  List<dynamic> searchResults = [];
  bool isSearching = false;

  Future<void> _searchCaptain() async {
    if (searchQuery.isEmpty) return;
    setState(() => isSearching = true);
    try {
      final response = await supabase
          .from('profiles')
          .select('*, driver_wallets(*)')
          .eq('is_driver', true)
          .ilike('phone', '%$searchQuery%');
      setState(() {
        searchResults = response;
        isSearching = false;
      });
    } catch (e) {
      setState(() => isSearching = false);
    }
  }

  void _showTopUpDialog(dynamic captain) {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('إضافة رصيد: ${captain['full_name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المبلغ'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'السبب / ملاحظات'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amountText = amountController.text.trim();
                if (amountText.isEmpty) return;
                
                final amount = num.tryParse(amountText) ?? 0;
                final wallets = captain['driver_wallets'];
                final currentBalance = (wallets != null && wallets.isNotEmpty) ? wallets[0]['balance'] ?? 0 : 0;
                final newBalance = currentBalance + amount;

                try {
                  if (wallets != null && wallets.isNotEmpty) {
                    await supabase.from('driver_wallets').update({
                      'balance': newBalance,
                      'updated_at': DateTime.now().toUtc().toIso8601String(),
                    }).eq('driver_id', captain['id']);
                  } else {
                    await supabase.from('driver_wallets').insert({
                      'driver_id': captain['id'],
                      'balance': newBalance,
                    });
                  }

                  // Insert transaction record
                  await supabase.from('transactions').insert({
                    'driver_id': captain['id'],
                    // 'user_id': captain['id'], // Not strictly required if driver_id is present
                    'amount': amount.abs(), // Always positive
                    'type': amount >= 0 ? 'deposit' : 'withdrawal',
                    'status': 'success',
                    'provider': 'admin_manual',
                    'metadata': {
                      'reason': reasonController.text.trim(),
                      'added_by': 'admin_dashboard',
                      'net_amount': amount,
                    }
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الرصيد بنجاح وتسجيل العملية')));
                    _searchCaptain(); // Refresh list to show new balance
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                  }
                }
              },
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('محافظ الكباتن (البحث بالرقم)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => searchQuery = val,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _searchCaptain,
                icon: const Icon(Icons.search),
                label: const Text('بحث'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: isSearching
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final captain = searchResults[index];
                      final wallets = captain['driver_wallets'];
                      final currentBalance = (wallets != null && wallets is List && wallets.isNotEmpty) 
                          ? wallets[0]['balance'] 
                          : 0;
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.account_balance_wallet)),
                          title: Text(captain['full_name'] ?? 'بدون اسم'),
                          subtitle: Text('الرقم: ${captain['phone']}\nالرصيد الحالي: $currentBalance د.ع'),
                          trailing: ElevatedButton(
                            onPressed: () => _showTopUpDialog(captain),
                            child: const Text('إضافة / خصم رصيد'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
