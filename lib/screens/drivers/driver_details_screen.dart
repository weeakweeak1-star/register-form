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
  String? _selectedImageUrl;
  String _selectedImageTitle = '';

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
        if (response != null) {
          _selectedImageUrl = response['profile_picture_url'];
          _selectedImageTitle = 'الصورة الشخصية';
        }
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
            decoration: const InputDecoration(labelText: 'يرجى كتابة سبب الرفض', border: OutlineInputBorder()),
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
                if (reasonController.text.trim().isEmpty) return;
                Navigator.pop(context);
                _updateStatus('rejected', reason: reasonController.text);
              },
              child: const Text('تأكيد الرفض', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Map<String, String?> _getDocuments() {
    if (documents == null) return {};
    return {
      'الصورة الشخصية': documents!['profile_picture_url'],
      'الهوية (وجه)': documents!['id_card_front_url'],
      'الهوية (ظهر)': documents!['id_card_back_url'],
      'إجازة السوق': documents!['license_url'],
      'السنوية (وجه)': documents!['car_reg_front_url'],
      'السنوية (ظهر)': documents!['car_reg_back_url'],
      'الوكالة': documents!['power_of_attorney_url'],
    };
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.driverData;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('ملف الكابتن: ${driver['full_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: Row(
        children: [
          // Left Side: Document Viewer (Flex 3)
          Expanded(
            flex: 3,
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildDocumentViewer(),
          ),
          
          // Right Side: Driver Info & Admin Tools (Flex 2)
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(-2, 0))],
              ),
              child: _buildInfoSection(driver),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentViewer() {
    final docs = _getDocuments();
    final validDocs = docs.entries.where((e) => e.value != null && e.value!.isNotEmpty).toList();

    if (documents == null || validDocs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('لم يتم العثور على مستمسكات لهذا الكابتن', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Main Image Viewer
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_selectedImageUrl != null && _selectedImageUrl!.isNotEmpty)
                    InteractiveViewer(
                      panEnabled: true,
                      scaleEnabled: true,
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.network(
                        _selectedImageUrl!,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Center(child: CircularProgressIndicator(value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null));
                        },
                      ),
                    )
                  else
                    const Center(child: Text('الرجاء اختيار صورة', style: TextStyle(fontSize: 18, color: Colors.grey))),
                  
                  // Title overlay
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        _selectedImageTitle,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Thumbnails Strip
        Container(
          height: 120,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: validDocs.length,
            itemBuilder: (context, index) {
              final doc = validDocs[index];
              final isSelected = _selectedImageUrl == doc.value;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedImageUrl = doc.value;
                    _selectedImageTitle = doc.key;
                  });
                },
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.indigo : Colors.grey.shade300,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(doc.value!, fit: BoxFit.cover),
                        Container(
                          color: isSelected ? Colors.transparent : Colors.black.withOpacity(0.3),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black.withOpacity(0.6),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              doc.key,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(Map<String, dynamic> driver) {
    final status = driver['driver_status'] ?? 'pending';
    
    Color statusColor;
    switch (status) {
      case 'approved': statusColor = Colors.green; break;
      case 'rejected': statusColor = Colors.red; break;
      case 'suspended': statusColor = Colors.orange; break;
      default: statusColor = Colors.grey; break;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Driver Avatar & Main Info
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.indigo.shade50,
                  backgroundImage: documents != null && documents!['profile_picture_url'] != null
                      ? NetworkImage(documents!['profile_picture_url'])
                      : null,
                  child: documents == null || documents!['profile_picture_url'] == null
                      ? Icon(Icons.person, size: 50, color: Colors.indigo.shade200)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(driver['full_name'] ?? 'بدون اسم', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(driver['phone'] ?? '', style: TextStyle(fontSize: 16, color: Colors.grey.shade800)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    'الحالة: $status',
                    style: TextStyle(fontWeight: FontWeight.bold, color: statusColor.withOpacity(0.9)),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          
          // Rejection Reason (If any)
          if (status == 'rejected' || status == 'suspended')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 24),
                      const SizedBox(width: 8),
                      Text('سبب التقييد / الرفض', style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(driver['reject_reason'] ?? 'غير محدد', style: TextStyle(color: Colors.red.shade900)),
                ],
              ),
            ),
            
          // Registration Date
          Row(
            children: [
              Icon(Icons.date_range, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Text('تاريخ التسجيل: ', style: TextStyle(color: Colors.grey.shade600)),
              Text(driver['created_at']?.toString().split('T')[0] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),

          const SizedBox(height: 32),
          const Text('أدوات الإدارة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
          const SizedBox(height: 16),
          
          // Admin Tools Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: [
              _buildToolButton(
                title: 'تعديل البيانات',
                icon: Icons.edit_document,
                color: Colors.blue,
                onTap: () async {
                  final result = await showDialog(
                    context: context,
                    builder: (context) => EditDriverDialog(driverData: driver),
                  );
                  if (result == true) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التحديث، يرجى إعادة تحميل الصفحة')));
                  }
                },
              ),
              _buildToolButton(
                title: 'الموقع الحي',
                icon: Icons.location_on,
                color: Colors.orange,
                onTap: () => showDialog(
                  context: context,
                  builder: (context) => DriverLocationModal(driverId: driver['id'], driverName: driver['full_name']),
                ),
              ),
              _buildToolButton(
                title: 'المحفظة المالية',
                icon: Icons.account_balance_wallet,
                color: Colors.teal,
                onTap: () => showDialog(
                  context: context,
                  builder: (context) => DriverWalletModal(driverId: driver['id'], driverName: driver['full_name']),
                ),
              ),
              _buildToolButton(
                title: 'سجل الرحلات',
                icon: Icons.history,
                color: Colors.purple,
                onTap: () => showDialog(
                  context: context,
                  builder: (context) => DriverTripsModal(driverId: driver['id'], driverName: driver['full_name']),
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Main Actions
          if (status != 'approved')
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('قبول وتفعيل الكابتن', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _updateStatus('approved'),
              ),
            ),
            
          if (status != 'approved' && status != 'rejected')
            const SizedBox(height: 16),
            
          if (status != 'rejected')
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('تقييد / رفض الكابتن', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade700,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _showRejectDialog,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolButton({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: color.withOpacity(0.9), fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
