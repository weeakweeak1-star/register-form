import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../main.dart';

class AdminReviewScreen extends StatefulWidget {
  final String applicationId;
  const AdminReviewScreen({super.key, required this.applicationId});

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen> {
  Map<String, dynamic>? _appData;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _selectedImageUrl;
  String _selectedImageTitle = '';

  final _formKey = GlobalKey<FormState>();
  final _carTypeController = TextEditingController();
  final _carModelController = TextEditingController();
  final _carColorController = TextEditingController();
  final _plateGovCodeController = TextEditingController();
  final _plateLetterController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _carSeatsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchApplication();
  }

  Future<void> _fetchApplication() async {
    try {
      final data = await supabase
          .from('driver_applications')
          .select()
          .eq('id', widget.applicationId)
          .single();
      setState(() {
        _appData = data;
        _selectedImageUrl = data['profile_picture_url'];
        _selectedImageTitle = 'الصورة الشخصية';
      });
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approve() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await supabase.from('driver_applications').update({
        'status': 'approved',
        'car_type': _carTypeController.text.trim(),
        'car_model': _carModelController.text.trim(),
        'car_color': _carColorController.text.trim(),
        'car_plate': '${_plateNumberController.text.trim()} - ${_plateLetterController.text.trim()} - ${_plateGovCodeController.text.trim()}',
        'car_seats': int.tryParse(_carSeatsController.text.trim()) ?? 4,
      }).eq('id', widget.applicationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الموافقة وتفعيل الكابتن بنجاح')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
                _reject(reasonController.text.trim());
              },
              child: const Text('تأكيد الرفض', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _reject(String reason) async {
    setState(() => _isSaving = true);
    try {
      await supabase.from('driver_applications').update({
        'status': 'rejected',
        'reject_reason': reason,
      }).eq('id', widget.applicationId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض الطلب')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Map<String, String?> _getDocuments() {
    if (_appData == null) return {};
    return {
      'الصورة الشخصية': _appData!['profile_picture_url'],
      'الهوية (وجه)': _appData!['id_card_front_url'],
      'الهوية (ظهر)': _appData!['id_card_back_url'],
      'إجازة السوق': _appData!['license_url'],
      'السنوية (وجه)': _appData!['car_reg_front_url'],
      'السنوية (ظهر)': _appData!['car_reg_back_url'],
      'الوكالة': _appData!['power_of_attorney_url'],
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_appData == null) return const Scaffold(body: Center(child: Text('الطلب غير موجود')));

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('مراجعة طلب: ${_appData!['full_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: Row(
        children: [
          // Left Side: Document Viewer (Flex 3)
          Expanded(
            flex: 3,
            child: _buildDocumentViewer(),
          ),
          
          // Right Side: Form & Info (Flex 2)
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(-2, 0))],
              ),
              child: _buildFormSection(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentViewer() {
    final docs = _getDocuments();
    final validDocs = docs.entries.where((e) => e.value != null && e.value!.isNotEmpty).toList();

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
                    const Center(child: Text('لا توجد صورة', style: TextStyle(fontSize: 18, color: Colors.grey))),
                  
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

  Widget _buildFormSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Header
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundImage: NetworkImage(_appData!['profile_picture_url'] ?? ''),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_appData!['full_name'] ?? 'بدون اسم', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(_appData!['phone_number'] ?? '', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Rejected Status
            if (_appData!['status'] == 'rejected')
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('هذا الطلب تم رفضه', style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('السبب: ${_appData!['reject_reason'] ?? 'غير محدد'}', style: TextStyle(color: Colors.red.shade900)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Car Details Form
            const Text('بيانات سيارة الكابتن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('يرجى مطابقة هذه البيانات مع صورة السنوية لتجنب أي أخطاء.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            _buildModernTextField(
              controller: _carTypeController,
              label: 'نوع السيارة',
              hint: 'مثال: هونداي',
              icon: Icons.directions_car_rounded,
            ),
            const SizedBox(height: 16),
            _buildModernTextField(
              controller: _carModelController,
              label: 'موديل السيارة',
              hint: 'مثال: إلنترا 2020',
              icon: Icons.style_rounded,
            ),
            const SizedBox(height: 16),
            _buildModernTextField(
              controller: _carColorController,
              label: 'اللون',
              hint: 'مثال: أبيض',
              icon: Icons.color_lens_rounded,
            ),
            const SizedBox(height: 16),
            _buildModernTextField(
              controller: _carSeatsController,
              label: 'عدد المقاعد',
              hint: 'مثال: 4',
              icon: Icons.airline_seat_recline_normal_rounded,
              keyboardType: TextInputType.number,
            ),
            
            const SizedBox(height: 24),
            const Text('رقم اللوحة المرورية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            IraqiLicensePlate(
              govCodeController: _plateGovCodeController,
              letterController: _plateLetterController,
              numberController: _plateNumberController,
            ),

            const SizedBox(height: 40),

            // Actions
            if (_isSaving)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade700,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('رفض الطلب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: _showRejectDialog,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('مطابق - قبول الكابتن', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: _approve,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.indigo.shade300),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.indigo.shade400, width: 2)),
      ),
      validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
    );
  }
}

// Widget for the beautiful Iraqi License Plate
class IraqiLicensePlate extends StatelessWidget {
  final TextEditingController govCodeController;
  final TextEditingController letterController;
  final TextEditingController numberController;

  const IraqiLicensePlate({
    super.key,
    required this.govCodeController,
    required this.letterController,
    required this.numberController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black87, width: 2.5),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // IRAQ vertical text
            Container(
              width: 35,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Colors.black87, width: 1.5)),
              ),
              child: const Center(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    'IRAQ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 2, color: Colors.black87),
                  ),
                ),
              ),
            ),
            
            // Gov Code
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: govCodeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.black87),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '11',
                  hintStyle: TextStyle(color: Colors.black26),
                  contentPadding: EdgeInsets.zero,
                ),
                validator: (v) => v!.isEmpty ? '*' : null,
              ),
            ),
            
            // Letter
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: letterController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.black87),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'C',
                  hintStyle: TextStyle(color: Colors.black26),
                  contentPadding: EdgeInsets.zero,
                ),
                validator: (v) => v!.isEmpty ? '*' : null,
              ),
            ),
            
            // Number
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: numberController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.black87),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '54543',
                  hintStyle: TextStyle(color: Colors.black26),
                  contentPadding: EdgeInsets.zero,
                ),
                validator: (v) => v!.isEmpty ? '*' : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
