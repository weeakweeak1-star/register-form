import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditDriverDialog extends StatefulWidget {
  final Map<String, dynamic> driverData;

  const EditDriverDialog({super.key, required this.driverData});

  @override
  State<EditDriverDialog> createState() => _EditDriverDialogState();
}

class _EditDriverDialogState extends State<EditDriverDialog> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.driverData['full_name']);
    _phoneController = TextEditingController(text: widget.driverData['phone']);
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await _supabase.from('profiles').update({
        'full_name': _nameController.text,
        'phone': _phoneController.text,
      }).eq('id', widget.driverData['id']);
      
      if (mounted) {
        Navigator.pop(context, true); // true indicates success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل بيانات الكابتن'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'الاسم الكامل'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'رقم الهاتف'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('حفظ'),
        ),
      ],
    );
  }
}
