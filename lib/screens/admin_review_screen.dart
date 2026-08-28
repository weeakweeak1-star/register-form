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
      setState(() => _appData = data);
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
      // 1. Update driver application (The database trigger will automatically update the profile)
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_appData == null) return const Scaffold(body: Center(child: Text('الطلب غير موجود')));

    return Scaffold(
      appBar: AppBar(title: Text('مراجعة طلب: ${_appData!['full_name']}')),
      body: Row(
        children: [
          // Left side: Images
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageCard('الصورة الشخصية', _appData!['profile_picture_url']),
                  _buildImageCard('الهوية الوطنية (وجه)', _appData!['id_card_front_url']),
                  _buildImageCard('الهوية الوطنية (ظهر)', _appData!['id_card_back_url']),
                  _buildImageCard('إجازة السوق', _appData!['license_url']),
                  _buildImageCard('سنوية السيارة (وجه)', _appData!['car_reg_front_url']),
                  _buildImageCard('سنوية السيارة (ظهر)', _appData!['car_reg_back_url']),
                  if (_appData!['power_of_attorney_url'] != null)
                    _buildImageCard('الوكالة المرورية', _appData!['power_of_attorney_url']),
                ],
              ),
            ),
          ),
          // Right side: Form & Actions
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_appData!['status'] == 'rejected')
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          border: Border.all(color: Colors.red),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('هذا الطلب مرفوض', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('السبب: ${_appData!['reject_reason'] ?? 'غير محدد'}', style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    const Text('بيانات السيارة (من السنوية)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _carTypeController,
                      decoration: const InputDecoration(labelText: 'النوع (مثال: هونداي)', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _carModelController,
                      decoration: const InputDecoration(labelText: 'الموديل (مثال: إلنترا 2020)', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _carColorController,
                      decoration: const InputDecoration(labelText: 'اللون', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('رقم اللوحة (كما في السنوية)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
                          const SizedBox(height: 12),
                          Directionality(
                            textDirection: TextDirection.ltr, // To force layout like the actual license plate
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _plateGovCodeController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(labelText: 'المحافظة', border: OutlineInputBorder()),
                                    validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text('-', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _plateLetterController,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(labelText: 'الحرف', border: OutlineInputBorder()),
                                    validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text('-', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _plateNumberController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(labelText: 'الرقم', border: OutlineInputBorder()),
                                    validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _carSeatsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'عدد المقاعد (مثال: 4)', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                    ),
                    const Spacer(),
                    if (_isSaving) const Center(child: CircularProgressIndicator()),
                    if (!_isSaving) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          onPressed: _approve,
                          child: const Text('موافقة وقبول الكابتن'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          onPressed: _showRejectDialog,
                          child: const Text('رفض الطلب'),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard(String title, String url) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Image.network(url, fit: BoxFit.contain),
          ],
        ),
      ),
    );
  }
}
