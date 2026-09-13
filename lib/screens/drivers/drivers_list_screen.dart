import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'driver_details_screen.dart';
import 'components/edit_driver_dialog.dart';
import 'components/driver_location_modal.dart';
import 'components/driver_wallet_modal.dart';
import 'components/driver_trips_modal.dart';
import '../../shared/components/pagination_controls.dart';

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
  
  // Pagination State
  int currentPage = 0;
  final int itemsPerPage = 25;

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
  }

  Future<void> _fetchDrivers() async {
    setState(() {
      isLoading = true;
      currentPage = 0;
    });
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('is_driver', true);

      // Fetch completed trips for counts safely
      List<dynamic> tripsResponse = [];
      try {
        tripsResponse = await supabase
            .from('trips')
            .select('driver_id')
            .eq('status', 'completed');
      } catch (e) {
        debugPrint('Error fetching trips for counts: $e');
      }

      List<dynamic> taxiResponse = [];
      try {
        taxiResponse = await supabase
            .from('taxi_requests')
            .select('driver_id')
            .eq('status', 'completed');
      } catch (e) {
        debugPrint('Error fetching taxi requests for counts: $e');
      }

      final Map<String, int> tripsCountMap = {};
      
      for (var row in tripsResponse) {
        final driverId = row['driver_id']?.toString();
        if (driverId != null) {
          tripsCountMap[driverId] = (tripsCountMap[driverId] ?? 0) + 1;
        }
      }
      
      for (var row in taxiResponse) {
        final driverId = row['driver_id']?.toString();
        if (driverId != null) {
          tripsCountMap[driverId] = (tripsCountMap[driverId] ?? 0) + 1;
        }
      }

      final List<Map<String, dynamic>> processedDrivers = [];
      for (var driver in response) {
        final driverMap = Map<String, dynamic>.from(driver);
        final driverId = driverMap['id']?.toString();
        driverMap['completed_trips_count'] = tripsCountMap[driverId] ?? 0;
        processedDrivers.add(driverMap);
      }

      // Sort by completed trips descending, then by created_at
      processedDrivers.sort((a, b) {
        final countA = a['completed_trips_count'] as int;
        final countB = b['completed_trips_count'] as int;
        if (countA != countB) {
          return countB.compareTo(countA);
        }
        final dateA = DateTime.tryParse(a['created_at'].toString()) ?? DateTime.now();
        final dateB = DateTime.tryParse(b['created_at'].toString()) ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      setState(() {
        drivers = processedDrivers;
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

    final paginatedDrivers = filteredDrivers.skip(currentPage * itemsPerPage).take(itemsPerPage).toList();

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
                      currentPage = 0;
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
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              itemCount: paginatedDrivers.length,
                              itemBuilder: (context, index) {
                                final driver = paginatedDrivers[index];
                          final status = driver['driver_status'] ?? 'pending';
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: driver['avatar_url'] != null ? NetworkImage(driver['avatar_url']) : null,
                                child: driver['avatar_url'] == null ? const Icon(Icons.person) : null,
                              ),
                              title: Text(driver['full_name'] ?? 'بدون اسم'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${driver['phone'] ?? ''} - الحالة: $status'),
                                  Text(
                                    'الرحلات المكتملة: ${driver['completed_trips_count'] ?? 0}',
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.location_on, color: Colors.blueGrey),
                                    tooltip: 'الموقع الحي',
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (context) => DriverLocationModal(
                                        driverId: driver['id'],
                                        driverName: driver['full_name'] ?? 'بدون اسم',
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.account_balance_wallet, color: Colors.orange),
                                    tooltip: 'المحفظة',
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (context) => DriverWalletModal(
                                        driverId: driver['id'],
                                        driverName: driver['full_name'] ?? 'بدون اسم',
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.history, color: Colors.teal),
                                    tooltip: 'سجل الرحلات',
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (context) => DriverTripsModal(
                                        driverId: driver['id'],
                                        driverName: driver['full_name'] ?? 'بدون اسم',
                                      ),
                                    ),
                                  ),
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
                    PaginationControls(
                      currentPage: currentPage,
                      totalItems: filteredDrivers.length,
                      itemsPerPage: itemsPerPage,
                      onNext: () {
                        setState(() {
                          currentPage++;
                        });
                      },
                      onPrevious: () {
                        setState(() {
                          currentPage--;
                        });
                      },
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}
