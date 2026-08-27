import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'driver_details_screen.dart';

class DriversListScreen extends StatefulWidget {
  const DriversListScreen({super.key});

  @override
  State<DriversListScreen> createState() => _DriversListScreenState();
}

class _DriversListScreenState extends State<DriversListScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<dynamic> drivers = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
  }

  Future<void> _fetchDrivers() async {
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('is_driver', true)
          .order('created_at', ascending: false);
      setState(() {
        drivers = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في جلب البيانات: $e')));
      }
    }
  }

  Future<void> _updateDriverStatus(String id, String status) async {
    try {
      await supabase.from('profiles').update({'driver_status': status}).eq('id', id);
      _fetchDrivers(); // Refresh list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في تحديث الحالة: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredDrivers = drivers.where((driver) {
      final name = driver['full_name']?.toString().toLowerCase() ?? '';
      final phone = driver['phone']?.toString().toLowerCase() ?? '';
      final q = searchQuery.toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'ابحث عن كابتن (الاسم أو رقم الهاتف)',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _fetchDrivers,
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredDrivers.isEmpty
                    ? const Center(child: Text('لا يوجد كباتن'))
                    : ListView.builder(
                        itemCount: filteredDrivers.length,
                        itemBuilder: (context, index) {
                          final driver = filteredDrivers[index];
                          final status = driver['driver_status'] ?? 'pending';
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: driver['avatar_url'] != null ? NetworkImage(driver['avatar_url']) : null,
                                child: driver['avatar_url'] == null ? const Icon(Icons.person) : null,
                              ),
                              title: Text(driver['full_name'] ?? 'بدون اسم'),
                              subtitle: Text('${driver['phone'] ?? ''} - الحالة: $status'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                    if (status != 'approved')
                                      IconButton(
                                        icon: const Icon(Icons.check, color: Colors.green),
                                        tooltip: 'تفعيل',
                                        onPressed: () => _updateDriverStatus(driver['id'], 'approved'),
                                      ),
                                  if (status != 'suspended')
                                    IconButton(
                                      icon: const Icon(Icons.block, color: Colors.red),
                                      tooltip: 'حظر',
                                      onPressed: () => _updateDriverStatus(driver['id'], 'suspended'),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.visibility, color: Colors.blue),
                                    tooltip: 'عرض المستمسكات',
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DriverDetailsScreen(driverData: driver),
                                        ),
                                      );
                                      if (result == true) {
                                        _fetchDrivers(); // Refresh list if status changed
                                      }
                                    },
                                  ),
                                ],
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
