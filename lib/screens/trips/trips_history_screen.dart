import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/components/pagination_controls.dart';

class TripsHistoryScreen extends StatefulWidget {
  const TripsHistoryScreen({super.key});

  @override
  State<TripsHistoryScreen> createState() => _TripsHistoryScreenState();
}

class _TripsHistoryScreenState extends State<TripsHistoryScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<dynamic> trips = [];
  bool isLoading = true;
  
  // Pagination State
  int currentPage = 0;
  final int itemsPerPage = 25;
  
  List<dynamic> get paginatedTrips {
    final startIndex = currentPage * itemsPerPage;
    return trips.skip(startIndex).take(itemsPerPage).toList();
  }

  // Filters State
  String searchQuery = '';
  String searchType = 'رقم الرحلة'; // 'رقم الرحلة' or 'اسم الكابتن'
  String selectedStatus = 'الكل';
  String selectedType = 'الكل';
  DateTimeRange? selectedDateRange;

  // Search Controllers
  final TextEditingController _searchController = TextEditingController();

  final List<String> searchTypes = ['رقم الرحلة', 'اسم الكابتن'];
  final List<String> statuses = ['الكل', 'completed', 'cancelled', 'scheduled'];
  final List<String> tripTypes = ['الكل', 'taxi', 'pool', 'intercity'];

  String _translateTripType(String type) {
    switch (type) {
      case 'taxi': return 'تكسي';
      case 'pool': return 'مشاركة (Pool)';
      case 'intercity': return 'بين المحافظات';
      default: return type;
    }
  }

  int totalCompletedTrips = 0;

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '-';
    try {
      final date = DateTime.parse(isoDate).toLocal();
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final amPm = date.hour >= 12 ? 'م' : 'ص';
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $hour:${date.minute.toString().padLeft(2, '0')} $amPm';
    } catch (e) {
      return isoDate;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _fetchTotalCompletedTrips();
  }

  Future<void> _fetchTotalCompletedTrips() async {
    int tripsCount = 0;
    int taxiCount = 0;

    try {
      tripsCount = await supabase
          .from('trips')
          .count(CountOption.exact)
          .eq('status', 'completed');
    } catch (e) {
      debugPrint('Error fetching trips count: $e');
    }

    try {
      taxiCount = await supabase
          .from('taxi_requests')
          .count(CountOption.exact)
          .eq('status', 'completed');
    } catch (e) {
      debugPrint('Error fetching taxi requests count: $e');
    }

    if (mounted) {
      setState(() {
        totalCompletedTrips = tripsCount + taxiCount;
      });
    }
  }

  Future<void> _fetchHistory() async {
    setState(() {
      isLoading = true;
      currentPage = 0;
    });
    try {
      final String selectBookings = '*, passenger:profiles!passenger_id(full_name, phone), trip:trips!inner(*, driver:profiles!driver_id(full_name, phone))';
      final String selectTaxi = '*, driver:profiles!driver_id(full_name, phone), customer:profiles!passenger_id(full_name, phone)';

      var bookingsQuery = supabase.from('bookings').select(selectBookings);
      var taxiQuery = supabase.from('taxi_requests').select(selectTaxi);

      // Status Filter
      if (selectedStatus != 'الكل') {
        bookingsQuery = bookingsQuery.eq('status', selectedStatus);
        taxiQuery = taxiQuery.eq('status', selectedStatus);
      } else {
        bookingsQuery = bookingsQuery.neq('status', 'ongoing'); 
        taxiQuery = taxiQuery.neq('status', 'ongoing'); 
      }

      bool fetchBookings = true;
      bool fetchTaxi = true;
      
      if (selectedType != 'الكل') {
        if (selectedType == 'taxi') {
          fetchBookings = false;
        } else {
          fetchTaxi = false;
          if (selectedType == 'pool') {
            bookingsQuery = bookingsQuery.eq('trip.is_private', false);
          } else if (selectedType == 'intercity') {
            bookingsQuery = bookingsQuery.eq('trip.is_private', true);
          }
        }
      }

      // Date Filter
      if (selectedDateRange != null) {
        bookingsQuery = bookingsQuery.gte('created_at', selectedDateRange!.start.toIso8601String())
                               .lte('created_at', selectedDateRange!.end.add(const Duration(days: 1)).toIso8601String());
        taxiQuery = taxiQuery.gte('created_at', selectedDateRange!.start.toIso8601String())
                             .lte('created_at', selectedDateRange!.end.add(const Duration(days: 1)).toIso8601String());
      }

      // Search Query Filter for Driver Name
      if (searchQuery.isNotEmpty && searchType == 'اسم الكابتن') {
        // PostgREST doesn't support ilike on foreign tables easily in the same query without inner joins.
        // We will fetch more and filter locally for simplicity if needed, or use inner join.
        // For now, we fetch and let local filter handle it to avoid complex joins.
      }

      int fetchLimit = (searchQuery.isNotEmpty) ? 1000 : 100;
      
      List<dynamic> combined = [];
      
      if (fetchBookings) {
        try {
          final bookingsResponse = await bookingsQuery.order('created_at', ascending: false).limit(fetchLimit);
          for(var b in bookingsResponse) {
              final m = Map<String,dynamic>.from(b);
              final tripData = m['trip'] ?? {};
              
              m['trip_type'] = (tripData['is_private'] == true) ? 'intercity' : 'pool';
              m['driver'] = tripData['driver'];
              m['customer'] = m['passenger'];
              
              m['booking_status'] = m['status'];
              m['trip_status'] = tripData['status'];
              m['status'] = m['status']; 
              m['trip_id'] = tripData['id'];
              m['mapped_origin'] = tripData['origin'];
              m['mapped_destination'] = tripData['destination'];
              m['mapped_price'] = tripData['price_per_seat'] ?? tripData['total_price'] ?? 0;
              m['is_booking'] = true;
              
              combined.add(m);
          }
        } catch (e) {
          debugPrint('Error fetching bookings: $e');
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching bookings: $e')));
        }
      }
      
      if (fetchTaxi) {
        try {
          final taxiResponse = await taxiQuery.order('created_at', ascending: false).limit(fetchLimit);
          for(var t in taxiResponse) {
              final m = Map<String,dynamic>.from(t);
              m['trip_type'] = 'taxi';
              // Map common fields
              m['mapped_origin'] = m['pickup_address'];
              m['mapped_destination'] = m['dropoff_address'];
              m['mapped_price'] = m['price'] ?? 0;
              combined.add(m);
          }
        } catch (e) {
          debugPrint('Error fetching taxi_requests: $e');
        }
      }

      // Local Filters
      if (searchQuery.isNotEmpty) {
        final queryStr = searchQuery.toLowerCase();
        combined = combined.where((trip) {
          if (searchType == 'رقم الرحلة') {
            return (trip['id']?.toString().toLowerCase() ?? '').contains(queryStr);
          } else if (searchType == 'اسم الكابتن') {
            return (trip['driver']?['full_name']?.toString().toLowerCase() ?? '').contains(queryStr);
          }
          return true;
        }).toList();
      }

      combined.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at'].toString()) ?? DateTime.now();
        final dateB = DateTime.tryParse(b['created_at'].toString()) ?? DateTime.now();
        return dateB.compareTo(dateA); // Descending
      });

      if (combined.length > fetchLimit) {
        combined = combined.sublist(0, fetchLimit);
      }

      setState(() {
        trips = combined;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching trips: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching trips: $e')));
        setState(() => isLoading = false);
      }
    }
  }

  void _clearFilters() {
    setState(() {
      searchQuery = '';
      _searchController.clear();
      searchType = 'رقم الرحلة';
      selectedStatus = 'الكل';
      selectedType = 'الكل';
      selectedDateRange = null;
    });
    _fetchHistory();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'scheduled': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'completed': return 'مكتملة';
      case 'cancelled': return 'ملغاة';
      case 'scheduled': return 'مجدولة';
      case 'pending': return 'قيد الانتظار';
      case 'accepted': return 'مقبولة';
      case 'confirmed': return 'مؤكدة';
      case 'rejected': return 'مرفوضة';
      case 'arrived': return 'وصل';
      case 'started': return 'بدأت';
      case 'ongoing': return 'جارية';
      default: return status;
    }
  }

  Future<void> _launchPhone(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رقم الهاتف غير متوفر')));
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن فتح تطبيق الاتصال')));
    }
  }

  void _showTripDetails(dynamic trip, String tripType) {
    final status = trip['status'] ?? 'unknown';
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.indigo),
              const SizedBox(width: 8),
              const Text('تفاصيل الرحلة', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('معرف الطلب (ID)', trip['id']?.toString() ?? '-'),
                  if (trip['is_booking'] == true)
                    _buildDetailRow('معرف الرحلة الأصلية', trip['trip_id']?.toString() ?? '-'),
                  const Divider(),
                  _buildDetailRow('نوع الطلب', tripType),
                  const Divider(),
                  if (trip['is_booking'] == true) ...[
                    _buildDetailRow('حالة الحجز (العميل)', _translateStatus(trip['booking_status'] ?? 'unknown'), valueColor: _getStatusColor(trip['booking_status'] ?? 'unknown')),
                    _buildDetailRow('حالة الرحلة (الكابتن)', _translateStatus(trip['trip_status'] ?? 'unknown'), valueColor: _getStatusColor(trip['trip_status'] ?? 'unknown')),
                  ] else ...[
                    _buildDetailRow('حالة الطلب', _translateStatus(status), valueColor: _getStatusColor(status)),
                  ],
                  const Divider(),
                  _buildDetailRow('تاريخ الإنشاء', _formatDate(trip['created_at'])),
                  const Divider(),
                  _buildDetailRow('العميل', trip['customer']?['full_name'] ?? 'غير متوفر'),
                  if (trip['customer']?['phone'] != null) ...[
                    const Divider(),
                    _buildDetailRow('هاتف العميل', trip['customer']['phone']),
                  ],
                  if (trip['is_booking'] == true) ...[
                     const Divider(),
                    _buildDetailRow('عدد المقاعد المحجوزة', trip['seats_booked']?.toString() ?? '1'),
                  ],
                  const Divider(),
                  _buildDetailRow('الكابتن', trip['driver']?['full_name'] ?? 'غير متوفر'),
                  if (trip['driver']?['phone'] != null) ...[
                    const Divider(),
                    _buildDetailRow('هاتف الكابتن', trip['driver']['phone']),
                  ],
                  const Divider(),
                  _buildDetailRow('نقطة الانطلاق', trip['mapped_origin'] ?? 'غير متوفر'),
                  const Divider(),
                  _buildDetailRow('نقطة الوصول', trip['mapped_destination'] ?? 'غير متوفر'),
                  const Divider(),
                  _buildDetailRow('السعر', '${trip['mapped_price']} د.ع'),
                  if (trip['seats'] != null) ...[
                    const Divider(),
                    _buildDetailRow('عدد المقاعد', trip['seats'].toString()),
                  ],
                  if (trip['scheduled_time'] != null) ...[
                    const Divider(),
                    _buildDetailRow('وقت الجدولة', _formatDate(trip['scheduled_time'])),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, color: valueColor ?? Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('سجل الرحلات المكتملة والملغاة', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final res = await supabase.from('bookings').select().limit(5);
                    if (mounted) {
                      showDialog(context: context, builder: (_) => AlertDialog(
                        title: const Text('Debug Bookings'),
                        content: Text('Count: ${res.length}\nData: $res'),
                      ));
                    }
                  } catch (e) {
                    if (mounted) {
                      showDialog(context: context, builder: (_) => AlertDialog(
                        title: const Text('Debug Error'),
                        content: Text(e.toString()),
                      ));
                    }
                  }
                },
                child: const Text('فحص الخلل (Debug)'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- Top Summary Card ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F9D58), Color(0xFF0B8043)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إجمالي الرحلات المكتملة',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'جميع الرحلات الناجحة في النظام',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.white, size: 40),
                    const SizedBox(width: 12),
                    Text(
                      '$totalCompletedTrips',
                      style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // --- Filter Section ---
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Search Type Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: searchType,
                            items: searchTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => searchType = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Search Field
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'ابحث عن رحلة...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onChanged: (val) => searchQuery = val,
                          onSubmitted: (_) => _fetchHistory(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Status Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration: InputDecoration(
                            labelText: 'حالة الرحلة',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s == 'الكل' ? 'الكل' : _translateStatus(s)))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => selectedStatus = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Type Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedType,
                          decoration: InputDecoration(
                            labelText: 'نوع الرحلة',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          items: tripTypes.map((t) => DropdownMenuItem(value: t, child: Text(t == 'الكل' ? 'الكل' : _translateTripType(t)))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => selectedType = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Date Range Picker
                      OutlinedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text(selectedDateRange == null 
                            ? 'تحديد فترة التاريخ' 
                            : '${selectedDateRange!.start.toString().split(' ')[0]} - ${selectedDateRange!.end.toString().split(' ')[0]}'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            initialDateRange: selectedDateRange,
                          );
                          if (picked != null) {
                            setState(() => selectedDateRange = picked);
                          }
                        },
                      ),
                      const Spacer(),
                      
                      // Clear Button
                      TextButton.icon(
                        icon: const Icon(Icons.clear_all),
                        label: const Text('مسح الفلاتر'),
                        onPressed: _clearFilters,
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                      const SizedBox(width: 12),
                      
                      // Apply Button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.filter_list),
                        label: const Text('تطبيق وبحث'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _fetchHistory,
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // --- List Section ---
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : trips.isEmpty
                    ? const Center(child: Text('لا توجد بيانات تطابق الفلاتر المحددة', style: TextStyle(fontSize: 16, color: Colors.grey)))
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              itemCount: paginatedTrips.length,
                              itemBuilder: (context, index) {
                                final trip = paginatedTrips[index];
                          final status = trip['status'] ?? 'unknown';
                                final tripType = _translateTripType(trip['trip_type'] ?? trip['type'] ?? 'غير محدد');
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _showTripDetails(trip, tripType),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    // Status Indicator
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status).withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        status == 'completed' ? Icons.check_circle : (status == 'cancelled' ? Icons.cancel : Icons.schedule),
                                        color: _getStatusColor(status),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // Trip Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'الكابتن: ${trip['driver']?['full_name'] ?? 'غير معروف'}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                              Row(
                                                children: [
                                                  if (trip['is_booking'] == true) ...[
                                                    Container(
                                                      margin: const EdgeInsets.only(left: 4),
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: _getStatusColor(trip['trip_status'] ?? '').withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: _getStatusColor(trip['trip_status'] ?? '')),
                                                      ),
                                                      child: Text(
                                                        'الرحلة: ${_translateStatus(trip['trip_status'] ?? '')}',
                                                        style: TextStyle(color: _getStatusColor(trip['trip_status'] ?? ''), fontSize: 10, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ],
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: _getStatusColor(status),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      trip['is_booking'] == true ? 'الحجز: ${_translateStatus(status)}' : _translateStatus(status),
                                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.confirmation_number_outlined, size: 16, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text('رقم الرحلة: ${trip['id']?.toString().substring(0, 8) ?? '-'}...', style: const TextStyle(color: Colors.grey)),
                                              const SizedBox(width: 16),
                                              const Icon(Icons.car_rental, size: 16, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text('النوع: $tripType', style: const TextStyle(color: Colors.grey)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text('التاريخ: ${_formatDate(trip['created_at'])}', style: const TextStyle(color: Colors.grey)),
                                              const SizedBox(width: 16),
                                              const Icon(Icons.attach_money, size: 16, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text('السعر: ${trip['mapped_price']} د.ع', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    PaginationControls(
                      currentPage: currentPage,
                      totalItems: trips.length,
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
