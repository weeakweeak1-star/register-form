import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart'; // To get supabase client

class ApplicationFormScreen extends StatefulWidget {
  const ApplicationFormScreen({super.key});

  @override
  State<ApplicationFormScreen> createState() => _ApplicationFormScreenState();
}

class _ApplicationFormScreenState extends State<ApplicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _scrollController = ScrollController();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  Uint8List? _profilePicBytes;
  Uint8List? _idFrontBytes;
  Uint8List? _idBackBytes;
  Uint8List? _carRegFrontBytes;
  Uint8List? _carRegBackBytes;
  Uint8List? _licenseBytes;
  Uint8List? _poaBytes;

  String? _profilePicExt, _idFrontExt, _idBackExt, _carRegFrontExt, _carRegBackExt, _licenseExt, _poaExt;

  bool _isLoading = false;
  bool _isSuccess = false;

  Future<void> _pickImage(String type) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // تقليل جودة الصورة لتقليل حجمها
      maxWidth: 1200, // تصغير أبعاد الصورة الكبيرة
      maxHeight: 1200,
    );
    if (image != null) {
      final ext = image.name.split('.').last.toLowerCase();
      // التأكد من أن الملف هو صورة
      if (!['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الرجاء اختيار ملف صورة صالح (JPG, PNG, WEBP)'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final bytes = await image.readAsBytes();
      
      // التحقق من حجم الصورة بحيث لا تتجاوز 500 كيلوبايت
      if (bytes.lengthInBytes > 500 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('حجم الصورة كبير جداً. الحد الأقصى هو 500 كيلوبايت.'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      setState(() {
        if (type == 'profilePic') {
          _profilePicBytes = bytes;
          _profilePicExt = ext;
        } else if (type == 'idFront') {
          _idFrontBytes = bytes;
          _idFrontExt = ext;
        } else if (type == 'idBack') {
          _idBackBytes = bytes;
          _idBackExt = ext;
        } else if (type == 'regFront') {
          _carRegFrontBytes = bytes;
          _carRegFrontExt = ext;
        } else if (type == 'regBack') {
          _carRegBackBytes = bytes;
          _carRegBackExt = ext;
        } else if (type == 'license') {
          _licenseBytes = bytes;
          _licenseExt = ext;
        } else if (type == 'poa') {
          _poaBytes = bytes;
          _poaExt = ext;
        }
      });
    }
  }

  Future<String?> _uploadFile(Uint8List bytes, String ext, String prefix) async {
    try {
      final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await supabase.storage.from('driver_documents').uploadBinary(fileName, bytes);
      return supabase.storage.from('driver_documents').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      // Scroll to top if validation fails so user sees the errors
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      return;
    }
    
    if (_profilePicBytes == null || _idFrontBytes == null || _idBackBytes == null || _carRegFrontBytes == null || _carRegBackBytes == null || _licenseBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى التأكد من رفع كافة المستمسكات الستة المطلوبة'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profilePicUrl = await _uploadFile(_profilePicBytes!, _profilePicExt ?? 'jpg', 'profile');
      final idFrontUrl = await _uploadFile(_idFrontBytes!, _idFrontExt ?? 'jpg', 'id_front');
      final idBackUrl = await _uploadFile(_idBackBytes!, _idBackExt ?? 'jpg', 'id_back');
      final regFrontUrl = await _uploadFile(_carRegFrontBytes!, _carRegFrontExt ?? 'jpg', 'reg_front');
      final regBackUrl = await _uploadFile(_carRegBackBytes!, _carRegBackExt ?? 'jpg', 'reg_back');
      final licenseUrl = await _uploadFile(_licenseBytes!, _licenseExt ?? 'jpg', 'license');
      
      String? poaUrl;
      if (_poaBytes != null) {
        poaUrl = await _uploadFile(_poaBytes!, _poaExt ?? 'jpg', 'poa');
      }

      if (profilePicUrl == null || idFrontUrl == null || idBackUrl == null || regFrontUrl == null || regBackUrl == null || licenseUrl == null || (_poaBytes != null && poaUrl == null)) {
        throw 'فشل رفع إحدى الصور. يرجى المحاولة مرة أخرى.';
      }

      await supabase.from('driver_applications').insert({
        'phone_number': _phoneController.text.trim(),
        'full_name': _nameController.text.trim(),
        'profile_picture_url': profilePicUrl,
        'id_card_front_url': idFrontUrl,
        'id_card_back_url': idBackUrl,
        'car_reg_front_url': regFrontUrl,
        'car_reg_back_url': regBackUrl,
        'license_url': licenseUrl,
        if (poaUrl != null) 'power_of_attorney_url': poaUrl,
      });

      setState(() {
        _isSuccess = true;
        _isLoading = false;
      });

    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 100),
              const SizedBox(height: 24),
              const Text('تم إرسال طلبك بنجاح!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('سنقوم بمراجعة مستمسكاتك والاتصال بك قريباً.\nيمكنك الآن إغلاق هذه الصفحة.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'انضم لكابتن وياك',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 8,
        shadowColor: const Color(0xFF0D47A1).withOpacity(0.5),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF002244), Color(0xFF0D47A1), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              'ابدأ رحلتك معنا وحقق أرباحك الآن! 🚗',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)],
          ),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('المعلومات الشخصية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'الاسم الثلاثي', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'يرجى كتابة اسمك' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      maxLength: 11,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف (مثل: 078xxxxxxx)', 
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'يرجى كتابة رقم هاتفك';
                        if (v.length != 11) return 'يجب أن يتكون رقم الهاتف من 11 رقماً';
                        if (!RegExp(r'^\d+$').hasMatch(v)) return 'يجب أن يحتوي الرقم على أرقام فقط';
                        if (!v.startsWith('07')) return 'يجب أن يبدأ الرقم بـ 07';
                        return null;
                      },
                    ),
                    
                    const Divider(height: 48),

                    const Text('المستمسكات المطلوبة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('يرجى التقاط أو اختيار صور واضحة للمستمسكات التالية:', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),

                    _buildFilePickerBtn('1. صورة شخصية واضحة (للكابتن)', 'profilePic', _profilePicBytes != null),
                    const SizedBox(height: 12),
                    _buildFilePickerBtn('2. الهوية الوطنية (وجه)', 'idFront', _idFrontBytes != null),
                    const SizedBox(height: 12),
                    _buildFilePickerBtn('3. الهوية الوطنية (ظهر)', 'idBack', _idBackBytes != null),
                    const SizedBox(height: 12),
                    _buildFilePickerBtn('4. سنوية السيارة (وجه)', 'regFront', _carRegFrontBytes != null),
                    const SizedBox(height: 12),
                    _buildFilePickerBtn('5. سنوية السيارة (ظهر)', 'regBack', _carRegBackBytes != null),
                    const SizedBox(height: 12),
                    _buildFilePickerBtn('6. إجازة السوق', 'license', _licenseBytes != null),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('ملاحظة هامة جداً:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'في حال كانت سنوية السيارة ليست باسمك (لا تطابق اسم البطاقة الموحدة)، يجب عليك رفع صورة (الوكالة المرورية) أدناه.',
                            style: TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                          const SizedBox(height: 12),
                          _buildFilePickerBtn('7. الوكالة المرورية (اختياري / إن وجدت)', 'poa', _poaBytes != null),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('إرسال الطلب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    // Adding extra space at the bottom to ensure the button is always visible when scrolling
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilePickerBtn(String title, String type, bool isPicked) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _pickImage(type),
        icon: Icon(isPicked ? Icons.check_circle : Icons.upload_file, color: isPicked ? Colors.green : null),
        label: Text(title + (isPicked ? ' (تم الرفع)' : ''), style: TextStyle(color: isPicked ? Colors.green : Colors.black87)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          alignment: Alignment.centerRight,
          side: BorderSide(color: isPicked ? Colors.green : Colors.grey.shade400),
        ),
      ),
    );
  }
}
