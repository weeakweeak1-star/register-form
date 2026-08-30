import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverWalletModal extends StatefulWidget {
  final String driverId;
  final String driverName;

  const DriverWalletModal({super.key, required this.driverId, required this.driverName});

  @override
  State<DriverWalletModal> createState() => _DriverWalletModalState();
}

class _DriverWalletModalState extends State<DriverWalletModal> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  double _balance = 0;
  List<Map<String, dynamic>> _transactions = [];
  final _amountController = TextEditingController();
  bool _isAddingBalance = false;

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
  }

  Future<void> _fetchWalletData() async {
    try {
      final walletResponse = await _supabase
          .from('driver_wallets')
          .select('balance')
          .eq('driver_id', widget.driverId)
          .limit(1)
          .maybeSingle();
      
      final txData = await _supabase
          .from('transactions')
          .select()
          .eq('driver_id', widget.driverId)
          .order('created_at', ascending: false)
          .limit(50);
          
      setState(() {
        if (walletResponse != null && walletResponse['balance'] != null) {
          _balance = (walletResponse['balance'] as num).toDouble();
        } else {
          _balance = 0.0;
        }
        _transactions = List<Map<String, dynamic>>.from(txData);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching wallet: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في جلب الرصيد: $e')));
      }
    }
  }

  Future<void> _addBalance() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return;
    
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال مبلغ صحيح')));
      return;
    }

    setState(() => _isAddingBalance = true);

    try {
      final txId = 'admin_${DateTime.now().millisecondsSinceEpoch}';
      
      await _supabase.rpc('process_payment_webhook', params: {
        'p_driver_id': widget.driverId,
        'p_amount': amount,
        'p_provider': 'system_admin',
        'p_provider_tx_id': txId,
        'p_metadata': {'added_by': _supabase.auth.currentUser?.id ?? 'admin'}
      });

      _amountController.clear();
      await _fetchWalletData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة الرصيد بنجاح')));
      }
    } catch (e) {
      debugPrint('Error adding balance: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء إضافة الرصيد: $e')));
      }
    } finally {
      if (mounted) setState(() => _isAddingBalance = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('محفظة الكابتن: ${widget.driverName}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            color: Colors.blue[50],
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('الرصيد الحالي', style: TextStyle(fontSize: 16, color: Colors.blueGrey)),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_balance.toStringAsFixed(0)} د.ع',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: _balance >= 0 ? Colors.green[700] : Colors.red[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text('إضافة رصيد (يدوي)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _amountController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'المبلغ',
                                    border: OutlineInputBorder(),
                                    suffixText: 'د.ع',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: _isAddingBalance ? null : _addBalance,
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                                  child: _isAddingBalance 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                                    : const Text('إيداع'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    const VerticalDivider(),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('سجل العمليات المالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _transactions.isEmpty
                                ? const Center(child: Text('لا توجد حركات مالية حتى الآن'))
                                : ListView.separated(
                                    itemCount: _transactions.length,
                                    separatorBuilder: (context, index) => const Divider(),
                                    itemBuilder: (context, index) {
                                      final tx = _transactions[index];
                                      final amount = (tx['amount'] as num).toDouble();
                                      final type = tx['type'] as String;
                                      final isDeposit = type == 'deposit' || type == 'trip_payment';
                                      
                                      String displayType = type;
                                      if (type == 'deposit') displayType = 'إيداع';
                                      if (type == 'withdrawal') displayType = 'سحب';
                                      if (type == 'commission') displayType = 'عمولة تطبيـق';
                                      if (type == 'trip_earning') displayType = 'أرباح رحلة';

                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: isDeposit ? Colors.green[100] : Colors.red[100],
                                          child: Icon(
                                            isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                                            color: isDeposit ? Colors.green : Colors.red,
                                          ),
                                        ),
                                        title: Text(displayType),
                                        subtitle: Text(tx['created_at'].toString().split('T').first),
                                        trailing: Text(
                                          '${isDeposit ? '+' : '-'}${amount.abs().toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDeposit ? Colors.green : Colors.red,
                                            fontSize: 16,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
