import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/components/pagination_controls.dart';
import 'components/customer_trips_modal.dart';
import 'components/customer_details_dialog.dart';
import 'components/send_customer_notification_dialog.dart';

class CustomersListScreen extends StatefulWidget {
  const CustomersListScreen({super.key});

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> customers = [];
  bool isLoading = true;
  String searchQuery = '';
  String filterType = 'passengers'; // 'passengers' (non-drivers) or 'all'

  // Pagination State
  int currentPage = 0;
  final int itemsPerPage = 25;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    setState(() {
      isLoading = true;
      currentPage = 0;
    });

    try {
      // 1. Fetch profiles
      dynamic response;
      if (filterType == 'passengers') {
        response = await supabase
            .from('profiles')
            .select()
            .or('is_driver.is.null,is_driver.eq.false')
            .order('created_at', ascending: false);
      } else {
        response = await supabase
            .from('profiles')
            .select()
            .order('created_at', ascending: false);
      }

      // 2. Fetch completed trips counts for passengers
      List<dynamic> taxiCompleted = [];
      try {
        taxiCompleted = await supabase
            .from('taxi_requests')
            .select('passenger_id')
            .eq('status', 'completed');
      } catch (e) {
        debugPrint('Error fetching completed taxi counts for customers: $e');
      }

      List<dynamic> bookingsCompleted = [];
      try {
        bookingsCompleted = await supabase
            .from('bookings')
            .select('passenger_id')
            .eq('status', 'completed');
      } catch (e) {
        debugPrint('Error fetching completed bookings counts for customers: $e');
      }

      final Map<String, int> countsMap = {};
      for (var row in taxiCompleted) {
        final pid = row['passenger_id']?.toString();
        if (pid != null) {
          countsMap[pid] = (countsMap[pid] ?? 0) + 1;
        }
      }

      for (var row in bookingsCompleted) {
        final pid = row['passenger_id']?.toString();
        if (pid != null) {
          countsMap[pid] = (countsMap[pid] ?? 0) + 1;
        }
      }

      final List<Map<String, dynamic>> processed = [];
      for (var user in (response as List<dynamic>)) {
        final userMap = Map<String, dynamic>.from(user);
        final uid = userMap['id']?.toString();
        userMap['completed_trips_count'] = countsMap[uid] ?? 0;
        processed.add(userMap);
      }

      // Sort: customers with highest completed trips first, then newest
      processed.sort((a, b) {
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
        customers = processed;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في جلب بيانات الزبائن: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCustomers = customers.where((c) {
      final name = c['full_name']?.toString().toLowerCase() ?? '';
      final phone = c['phone']?.toString().toLowerCase() ?? '';
      final email = c['email']?.toString().toLowerCase() ?? '';
      final q = searchQuery.toLowerCase().trim();
      return name.contains(q) || phone.contains(q) || email.contains(q);
    }).toList();

    final paginatedCustomers =
        filteredCustomers.skip(currentPage * itemsPerPage).take(itemsPerPage).toList();

    final totalCompletedTrips = filteredCustomers.fold<int>(
      0,
      (sum, item) => sum + (item['completed_trips_count'] as int? ?? 0),
    );

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Header Controls Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Search input
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'ابحث عن زبون بالاسم، رقم الهاتف، أو البريد...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              searchQuery = value;
                              currentPage = 0;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Filter dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: filterType,
                            items: const [
                              DropdownMenuItem(
                                value: 'passengers',
                                child: Text('الزبائن (الركاب فقط)', style: TextStyle(fontSize: 14)),
                              ),
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('جميع المستخدمين', style: TextStyle(fontSize: 14)),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null && val != filterType) {
                                setState(() {
                                  filterType = val;
                                });
                                _fetchCustomers();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Refresh button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _fetchCustomers,
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text('تحديث'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Quick Stats Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.people_alt, size: 16, color: Colors.blue.shade800),
                            const SizedBox(width: 6),
                            Text(
                              'إجمالي الزبائن: ${filteredCustomers.length}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, size: 16, color: Colors.green.shade800),
                            const SizedBox(width: 6),
                            Text(
                              'إجمالي الرحلات المنجزة للزبائن: $totalCompletedTrips',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Customers List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredCustomers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 70, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'لا يوجد زبائن مطابقين للبحث',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              itemCount: paginatedCustomers.length,
                              itemBuilder: (context, index) {
                                final customer = paginatedCustomers[index];
                                final name = customer['full_name'] ?? 'بدون اسم';
                                final phone = customer['phone'] ?? 'بدون هاتف';
                                final email = customer['email'];
                                final avatar = customer['avatar_url'];
                                final rating = customer['rating'] ?? 5.0;
                                final tripsCount = customer['completed_trips_count'] ?? 0;
                                final isDriver = customer['is_driver'] == true;

                                return Card(
                                  elevation: 0,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.indigo.shade50,
                                      backgroundImage: (avatar != null && avatar.isNotEmpty)
                                          ? NetworkImage(avatar)
                                          : null,
                                      child: (avatar == null || avatar.isEmpty)
                                          ? const Icon(Icons.person, color: Colors.indigo)
                                          : null,
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        if (isDriver) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade100,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              'كابتن أيضاً',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange.shade900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Wrap(
                                        spacing: 16,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Text(phone, style: TextStyle(color: Colors.grey.shade700)),
                                            ],
                                          ),
                                          if (email != null && email.isNotEmpty)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade600),
                                                const SizedBox(width: 4),
                                                Text(email, style: TextStyle(color: Colors.grey.shade700)),
                                              ],
                                            ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.star, size: 15, color: Colors.amber),
                                              const SizedBox(width: 3),
                                              Text(
                                                rating.toString(),
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.green.shade200),
                                            ),
                                            child: Text(
                                              'الرحلات المكتملة: $tripsCount',
                                              style: TextStyle(
                                                color: Colors.green.shade800,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Trips history modal button
                                        IconButton(
                                          icon: const Icon(Icons.history_edu, color: Colors.teal),
                                          tooltip: 'سجل رحلات وحجوزات الزبون',
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => CustomerTripsModal(
                                                customerId: customer['id'].toString(),
                                                customerName: name,
                                              ),
                                            );
                                          },
                                        ),
                                        // Send direct notification button
                                        IconButton(
                                          icon: const Icon(Icons.notifications_active, color: Colors.orange),
                                          tooltip: 'إرسال إشعار مباشر للزبون',
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => SendCustomerNotificationDialog(
                                                customerId: customer['id'].toString(),
                                                customerName: name,
                                              ),
                                            );
                                          },
                                        ),
                                        // Customer full profile details
                                        IconButton(
                                          icon: const Icon(Icons.visibility, color: Colors.blue),
                                          tooltip: 'عرض تفاصيل الحساب',
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => CustomerDetailsDialog(
                                                customerData: customer,
                                              ),
                                            );
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
                            totalItems: filteredCustomers.length,
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
