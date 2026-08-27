import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components/edit_driver_dialog.dart';
import 'components/driver_location_modal.dart';
import 'components/driver_wallet_modal.dart';
import 'components/driver_trips_modal.dart';

class DriverDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> driverData;

  const DriverDetailsScreen({super.key, required this.driverData});

  @override
  State<DriverDetailsScreen> createState() => _DriverDetailsScreenState();
}

class _DriverDetailsScreenState extends State<DriverDetailsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool isLoading = true;
  Map<String, dynamic>? documents;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    try {
      final phone = widget.driverData['phone']?.toString() ?? '';
      final phoneSuffix = phone.length > 10 ? phone.substring(phone.length - 10) : phone;

      final response = await supabase
          .from('driver_applications')
          .select()
          .like('phone_number', '%$phoneSuffix')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      setState(() {
        documents = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateStatus(String status, {String? reason}) async {
    try {
      final updateData = {'driver_status': status};
      if (reason != null) {
        updateData['reject_reason'] = reason;
      }
      await supabase.from('profiles').update(updateData).eq('id', widget.driverData['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تغيير الحالة إلى $status')));
        Navigator.pop(context, true); // Return true to indicate refresh is needed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  void _showRejectDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('سبب الرفض'),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(labelText: 'يرجى كتابة سبب الرفض'),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                _updateStatus('rejected', reason: reasonController.text);
                // Optionally save the reason in a separate table or column
              },
              child: const Text('تأكيد الرفض', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDocumentImage(String title, String? url) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            url != null && url.isNotEmpty
                ? Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey));
                    },
                  )
                : const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('لا توجد صورة'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.driverData;
    final status = driver['driver_status'] ?? 'pending';

    return Scaffold(
      appBar: AppBar(
        title: Text('طلب تسجيل: ${driver['full_name']}'),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side: Driver Info and Actions
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.grey[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
                  const SizedBox(height: 16),
                  Text('الاسم: ${driver['full_name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('رقم الهاتف: ${driver['phone']}', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('تاريخ التسجيل: ${driver['created_at']}', style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: status == 'approved' ? Colors.green[100] : (status == 'rejected' ? Colors.red[100] : Colors.orange[100]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('الحالة الحالية: $status', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  if (status == 'rejected' || status == 'suspended') ...[
                    const SizedBox(height: 8),
                    Text('السبب: ${driver['reject_reason'] ?? 'غير محدد'}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                  const SizedBox(height: 24),
                  const Divider(),
                  const Text('أدوات الإدارة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('تعديل المعلومات'),
                        onPressed: () async {
                          final result = await showDialog(
                            context: context,
                            builder: (context) => EditDriverDialog(driverData: driver),
                          );
                          if (result == true) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث البيانات بنجاح، يرجى التحديث لرؤية التغييرات')));
                          }
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.location_on, size: 18),
                        label: const Text('الموقع الحي'),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (context) => DriverLocationModal(
                            driverId: driver['id'],
                            driverName: driver['full_name'],
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.account_balance_wallet, size: 18),
                        label: const Text('المحفظة'),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (context) => DriverWalletModal(
                            driverId: driver['id'],
                            driverName: driver['full_name'],
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.history, size: 18),
                        label: const Text('سجل الرحلات'),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (context) => DriverTripsModal(
                            driverId: driver['id'],
                            driverName: driver['full_name'],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Actions
                  if (status != 'approved')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('قبول وتفعيل'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: () => _updateStatus('approved'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (status != 'rejected')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.close),
                        label: const Text('رفض الطلب'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: _showRejectDialog,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          // Right Side: Documents
          Expanded(
            flex: 2,
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('المستمسكات المرفقة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        _buildDocumentImage('الصورة الشخصية', documents?['profile_picture_url']),
                        _buildDocumentImage('الهوية الوطنية (وجه)', documents?['id_card_front_url']),
                        _buildDocumentImage('الهوية الوطنية (ظهر)', documents?['id_card_back_url']),
                        _buildDocumentImage('إجازة السوق', documents?['license_url']),
                        _buildDocumentImage('سنوية السيارة (وجه)', documents?['car_reg_front_url']),
                        _buildDocumentImage('سنوية السيارة (ظهر)', documents?['car_reg_back_url']),
                        if (documents?['power_of_attorney_url'] != null)
                          _buildDocumentImage('الوكالة المرورية', documents?['power_of_attorney_url']),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
