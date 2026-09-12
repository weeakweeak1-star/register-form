import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String _sendType = 'all'; // 'all' or 'specific'
  String _searchQuery = '';
  List<dynamic> _drivers = [];
  bool _isFetchingDrivers = false;
  String? _selectedDriverId;

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
  }

  Future<void> _fetchDrivers() async {
    setState(() => _isFetchingDrivers = true);
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, phone')
          .eq('is_driver', true);
      setState(() {
        _drivers = response as List<dynamic>;
      });
    } catch (e) {
      debugPrint('Error fetching drivers: $e');
    } finally {
      if (mounted) setState(() => _isFetchingDrivers = false);
    }
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.trim().isEmpty || _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال عنوان ونص الإشعار')),
      );
      return;
    }

    if (_sendType == 'specific' && _selectedDriverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الكابتن المستهدف')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _supabase.from('notifications').insert({
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'target_driver_id': _sendType == 'all' ? null : _selectedDriverId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الإشعار بنجاح!')),
      );
      
      _titleController.clear();
      _messageController.clear();
      setState(() {
        _selectedDriverId = null;
        _sendType = 'all';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الإرسال: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredDrivers = _drivers.where((driver) {
      final name = (driver['full_name'] ?? '').toString().toLowerCase();
      final phone = (driver['phone'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إرسال إشعارات (داخل التطبيق)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'عنوان الإشعار',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'نص الإشعار',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          const Text('نوع الإرسال:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Row(
            children: [
              Radio<String>(
                value: 'all',
                groupValue: _sendType,
                onChanged: (value) {
                  setState(() => _sendType = value!);
                },
              ),
              const Text('إرسال لجميع الكباتن'),
              const SizedBox(width: 24),
              Radio<String>(
                value: 'specific',
                groupValue: _sendType,
                onChanged: (value) {
                  setState(() => _sendType = value!);
                },
              ),
              const Text('إرسال لكابتن محدد'),
            ],
          ),
          if (_sendType == 'specific') ...[
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'ابحث عن كابتن (الاسم أو رقم الهاتف)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _selectedDriverId = null; // Reset selection when searching
                });
              },
            ),
            const SizedBox(height: 8),
            if (_isFetchingDrivers)
              const CircularProgressIndicator()
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListView.builder(
                  itemCount: filteredDrivers.length,
                  itemBuilder: (context, index) {
                    final driver = filteredDrivers[index];
                    final isSelected = _selectedDriverId == driver['id'];
                    return ListTile(
                      title: Text(driver['full_name'] ?? 'بدون اسم'),
                      subtitle: Text(driver['phone'] ?? 'لا يوجد رقم'),
                      selected: isSelected,
                      selectedTileColor: Colors.blue.withOpacity(0.1),
                      onTap: () {
                        setState(() {
                          _selectedDriverId = driver['id'];
                        });
                      },
                      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                    );
                  },
                ),
              ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendNotification,
              icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send),
              label: Text(_isLoading ? 'جاري الإرسال...' : 'إرسال الإشعار'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

