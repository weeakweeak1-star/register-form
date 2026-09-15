import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/components/pagination_controls.dart';

class LiveTripsScreen extends StatefulWidget {
  const LiveTripsScreen({super.key});

  @override
  State<LiveTripsScreen> createState() => _LiveTripsScreenState();
}

class _LiveTripsScreenState extends State<LiveTripsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<dynamic> allLiveTrips = [];
  List<dynamic> filteredTrips = [];
  bool isLoading = true;
  Timer? _pollingTimer;

  // Filters State
  String searchQuery = '';
  String searchType = 'رقم الرحلة'; // 'رقم الرحلة', 'اسم الكابتن', 'اسم العميل'
  String selectedStatus = 'الكل';
  bool sortAscending = false;

  // Pagination State
  int currentPage = 0;
  final int itemsPerPage = 25;

  final TextEditingController _searchController = TextEditingController();

  final List<String> tripTypes = ['الكل', 'taxi', 'pool', 'intercity'];

  String _translateTripType(String type) {
    switch (type) {
      case 'taxi': return 'تكسي';
      case 'pool': return 'مشاركة (Pool)';
      case 'intercity': return 'بين المحافظات';
      default: return type;
    }
  }

  // Active trip statuses
  final List<String> statuses = ['الكل', 'searching', 'accepted', 'arrived', 'ongoing'];

  @override
  void initState() {
    super.initState();
    _fetchLiveTrips();
    // Poll every 10 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchLiveTrips(isPolling: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveTrips({bool isPolling = false}) async {
    if (!isPolling) {
      setState(() => isLoading = true);
    }
    try {
      final String selectBookings = '*, passenger:profiles!passenger_id(full_name, phone), trip:trips!inner(*, driver:profiles!driver_id(full_name, phone))';
      final String selectTaxi = '*, driver:profiles!driver_id(full_name, phone), customer:profiles!passenger_id(full_name, phone)';

      final bookingsResponse = await supabase
          .from('bookings')
          .select(selectBookings)
          .inFilter('status', ['pending', 'confirmed', 'active', 'ongoing']);
          
      final taxiResponse = await supabase
          .from('taxi_requests')
          .select(selectTaxi)
          .inFilter('status', ['searching', 'accepted', 'arrived', 'ongoing', 'active']);
      
      List<dynamic> combined = [];
      
      for(var b in bookingsResponse) {
        final m = Map<String,dynamic>.from(b);
        final tripData = m['trip'] ?? {};
        m['trip_type'] = tripData['is_private'] == true ? 'intercity' : 'pool';
        m['customer'] = m['passenger'];
        m['driver'] = tripData['driver'];
        
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
      
      for(var t in taxiResponse) {
        final m = Map<String,dynamic>.from(t);
        m['trip_type'] = 'taxi';
        m['mapped_origin'] = m['pickup_address'];
        m['mapped_destination'] = m['dropoff_address'];
        m['mapped_price'] = m['price'] ?? 0;
        combined.add(m);
      }

      combined.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at'].toString()) ?? DateTime.now();
        final dateB = DateTime.tryParse(b['created_at'].toString()) ?? DateTime.now();
        return sortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
      });
      
      if (mounted) {
        setState(() {
          allLiveTrips = combined;
          _applyFilters();
          if (!isPolling) isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching live trips: $e');
      if (mounted && !isPolling) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => isLoading = false);
      }
    }
  }

  void _applyFilters() {
    filteredTrips = allLiveTrips.where((trip) {
      // 1. Status Filter
      if (selectedStatus != 'الكل' && trip['status'] != selectedStatus) {
        return false;
      }
      
      // 2. Trip Type Filter
      if (searchType != 'الكل' && trip['trip_type'] != searchType) {
        return false;
      }
      
      // 3. Search Filter
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final id = trip['id']?.toString().toLowerCase() ?? '';
        final driverName = trip['driver']?['full_name']?.toString().toLowerCase() ?? '';
        final customerName = trip['customer']?['full_name']?.toString().toLowerCase() ?? '';
        
        if (!id.contains(query) && !driverName.contains(query) && !customerName.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      searchQuery = '';
      _searchController.clear();
      searchType = 'الكل';
      selectedStatus = 'الكل';
      sortAscending = false;
      currentPage = 0;
    });
    _fetchLiveTrips();
  }

  Future<void> _forceCancelTrip(dynamic trip) async {
    final TextEditingController reasonController = TextEditingController();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إلغاء الرحلة بالقوة (Force Cancel)', style: TextStyle(color: Colors.red)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('هل أنت متأكد من إلغاء الرحلة رقم: ${trip['id'].toString().substring(0, 8)}... ؟'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'سبب الإلغاء (إجباري)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('تراجع'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال سبب الإلغاء')));
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('تأكيد الإلغاء'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await supabase.from('trips').update({
          'status': 'cancelled',
          'cancellation_reason': reasonController.text.trim(),
          'cancelled_by': 'admin',
        }).eq('id', trip['id']);
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إلغاء الرحلة بنجاح', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
        _fetchLiveTrips(); // Refresh
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red));
      }
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'searching': return Colors.orange;
      case 'accepted': return Colors.blue;
      case 'arrived': return Colors.purple;
      case 'ongoing': 
      case 'active': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'searching': return 'جاري البحث';
      case 'accepted': return 'في الطريق للعميل';
      case 'arrived': return 'الكابتن وصل';
      case 'ongoing': 
      case 'active': return 'الرحلة جارية';
      case 'completed': return 'مكتملة';
      case 'cancelled': return 'ملغاة';
      case 'scheduled': return 'مجدولة';
      case 'pending': return 'قيد الانتظار';
      case 'confirmed': return 'مؤكدة';
      case 'rejected': return 'مرفوضة';
      case 'started': return 'بدأت';
      default: return status;
    }
  }

  String _formatElapsedTime(String? isoDate) {
    if (isoDate == null) return '-';
    try {
      final date = DateTime.parse(isoDate).toLocal();
      final difference = DateTime.now().difference(date);
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} دقيقة';
      } else {
        return '${difference.inHours} ساعة و ${difference.inMinutes % 60} دقيقة';
      }
    } catch (e) {
      return '-';
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
                  _buildDetailRow('تاريخ الإنشاء', _formatDate(trip['created_at'] ?? '')),
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

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '-';
    try {
      final date = DateTime.parse(isoDate).toLocal();
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final amPm = date.hour >= 12 ? 'م' : 'ص';
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $hour:${date.minute.toString().padLeft(2, '0')} $amPm';
    } catch (e) {
      return isoDate;
    }
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
              const Text('غرفة العمليات - الرحلات الجارية', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  const Icon(Icons.circle, color: Colors.green, size: 12),
                  const SizedBox(width: 8),
                  Text('محدث تلقائياً', style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'تحديث الآن',
                    onPressed: () => _fetchLiveTrips(),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),

          // --- Filter Section ---
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
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
                            items: tripTypes.map((t) => DropdownMenuItem(value: t, child: Text(t == 'الكل' ? 'الكل' : _translateTripType(t)))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  searchType = val;
                                  currentPage = 0;
                                  _applyFilters();
                                });
                              }
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
                            hintText: 'ابحث...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onChanged: (val) {
                            setState(() {
                              searchQuery = val;
                              currentPage = 0;
                              _applyFilters();
                            });
                          },
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
                            if (val != null) {
                              setState(() {
                                selectedStatus = val;
                                currentPage = 0;
                                _applyFilters();
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: Icon(sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                        label: Text(sortAscending ? 'الأقدم أولاً' : 'الأحدث أولاً'),
                        onPressed: () {
                          setState(() {
                            sortAscending = !sortAscending;
                            _fetchLiveTrips();
                          });
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.clear_all),
                        label: const Text('مسح الفلاتر'),
                        onPressed: _clearFilters,
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
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
                : filteredTrips.isEmpty
                    ? const Center(child: Text('لا توجد رحلات جارية تطابق الفلاتر المحددة', style: TextStyle(fontSize: 16, color: Colors.grey)))
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              itemCount: filteredTrips.skip(currentPage * itemsPerPage).take(itemsPerPage).length,
                              itemBuilder: (context, index) {
                                final paginatedList = filteredTrips.skip(currentPage * itemsPerPage).take(itemsPerPage).toList();
                                final trip = paginatedList[index];
                                final status = trip['status'] ?? 'unknown';
                                final tripType = _translateTripType(trip['trip_type'] ?? trip['type'] ?? 'غير محدد');
                                
                                final customerName = trip['customer']?['full_name'] ?? 'متعدد (رحلة بين المحافظات)';
                                final customerPhone = trip['customer']?['phone'];
                                
                                final driverName = trip['driver']?['full_name'] ?? 'جاري البحث...';
                                final driverPhone = trip['driver']?['phone'];

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: _getStatusColor(status).withOpacity(0.5), width: 1),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // --- Header Row ---
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                if (trip['is_booking'] == true) ...[
                                                  Container(
                                                    margin: const EdgeInsets.only(left: 8),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: _getStatusColor(trip['trip_status'] ?? '').withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(20),
                                                      border: Border.all(color: _getStatusColor(trip['trip_status'] ?? '')),
                                                    ),
                                                    child: Text(
                                                      'الرحلة: ${_translateStatus(trip['trip_status'] ?? '')}',
                                                      style: TextStyle(color: _getStatusColor(trip['trip_status'] ?? ''), fontWeight: FontWeight.bold, fontSize: 11),
                                                    ),
                                                  ),
                                                ],
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(status),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Text(
                                                    trip['is_booking'] == true ? 'الحجز: ${_translateStatus(status)}' : _translateStatus(status),
                                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text('نوع الرحلة: $tripType', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                const Icon(Icons.timer, size: 16, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Text('منذ: ${_formatElapsedTime(trip['created_at'])}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 24),
                                        
                                        // --- Body Row ---
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Customer Info
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('العميل', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.person, size: 16, color: Colors.blueGrey),
                                                      const SizedBox(width: 4),
                                                      Expanded(child: Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold))),
                                                    ],
                                                  ),
                                                  if (customerPhone != null) ...[
                                                    const SizedBox(height: 4),
                                                    InkWell(
                                                      onTap: () => _launchPhone(customerPhone),
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.phone, size: 16, color: Colors.blue),
                                                          const SizedBox(width: 4),
                                                          Text(customerPhone, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                                                        ],
                                                      ),
                                                    ),
                                                  ]
                                                ],
                                              ),
                                            ),
                                            
                                            // Driver Info
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('الكابتن', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.drive_eta, size: 16, color: Colors.blueGrey),
                                                      const SizedBox(width: 4),
                                                      Expanded(child: Text(driverName, style: const TextStyle(fontWeight: FontWeight.bold))),
                                                    ],
                                                  ),
                                                  if (driverPhone != null) ...[
                                                    const SizedBox(height: 4),
                                                    InkWell(
                                                      onTap: () => _launchPhone(driverPhone),
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.phone, size: 16, color: Colors.blue),
                                                          const SizedBox(width: 4),
                                                          Text(driverPhone, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                                                        ],
                                                      ),
                                                    ),
                                                  ]
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        
                                        // Locations
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                                          child: Column(
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.my_location, color: Colors.green, size: 16),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: Text(trip['mapped_origin'] ?? 'غير محدد', maxLines: 1, overflow: TextOverflow.ellipsis)),
                                                ],
                                              ),
                                              const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 7),
                                                child: Align(alignment: Alignment.centerRight, child: Icon(Icons.more_vert, size: 16, color: Colors.grey)),
                                              ),
                                              Row(
                                                children: [
                                                  const Icon(Icons.location_on, color: Colors.red, size: 16),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: Text(trip['mapped_destination'] ?? 'غير محدد', maxLines: 1, overflow: TextOverflow.ellipsis)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 16),
                                        
                                        // --- Action Buttons ---
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              icon: const Icon(Icons.info_outline),
                                              label: const Text('تفاصيل'),
                                              onPressed: () {
                                                _showTripDetails(trip, tripType);
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.cancel),
                                              label: const Text('إلغاء إجباري'),
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red, elevation: 0),
                                              onPressed: () => _forceCancelTrip(trip),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          PaginationControls(
                            currentPage: currentPage,
                            totalItems: filteredTrips.length,
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
