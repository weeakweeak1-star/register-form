import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TripsHistoryScreen extends StatefulWidget {
  const TripsHistoryScreen({super.key});

  @override
  State<TripsHistoryScreen> createState() => _TripsHistoryScreenState();
}

class _TripsHistoryScreenState extends State<TripsHistoryScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<dynamic> trips = [];
  bool isLoading = true;

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
    try {
      final tripsCount = await supabase
          .from('trips')
          .count(CountOption.exact)
          .eq('status', 'completed');
          
      final taxiCount = await supabase
          .from('taxi_requests')
          .count(CountOption.exact)
          .eq('status', 'completed');
          
      setState(() {
        totalCompletedTrips = tripsCount + taxiCount;
      });
    } catch (e) {
      debugPrint('Error fetching completed trips count: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching count: $e')));
      }
    }
  }

  Future<void> _fetchHistory() async {
    setState(() => isLoading = true);
    try {
      final String selectStr = (searchQuery.isNotEmpty && searchType == 'اسم الكابتن') 
          ? '*, profiles!driver_id!inner(full_name)'
          : '*, profiles!driver_id(full_name)';

      var tripsQuery = supabase.from('trips').select(selectStr);
      var taxiQuery = supabase.from('taxi_requests').select(selectStr);

      // Status Filter
      if (selectedStatus != 'الكل') {
        tripsQuery = tripsQuery.eq('status', selectedStatus);
        taxiQuery = taxiQuery.eq('status', selectedStatus);
      } else {
        tripsQuery = tripsQuery.neq('status', 'ongoing'); 
        taxiQuery = taxiQuery.neq('status', 'ongoing'); 
      }

      // Type Filter logic:
      bool fetchTrips = true;
      bool fetchTaxi = true;
      
      if (selectedType != 'الكل') {
        if (selectedType == 'taxi') {
          fetchTrips = false;
        } else {
          fetchTaxi = false;
          tripsQuery = tripsQuery.eq('trip_type', selectedType); 
        }
      }

      // Date Filter
      if (selectedDateRange != null) {
        tripsQuery = tripsQuery.gte('created_at', selectedDateRange!.start.toIso8601String())
                               .lte('created_at', selectedDateRange!.end.add(const Duration(days: 1)).toIso8601String());
        taxiQuery = taxiQuery.gte('created_at', selectedDateRange!.start.toIso8601String())
                             .lte('created_at', selectedDateRange!.end.add(const Duration(days: 1)).toIso8601String());
      }

      // Search Query Filter for Driver Name
      if (searchQuery.isNotEmpty && searchType == 'اسم الكابتن') {
        tripsQuery = tripsQuery.ilike('profiles.full_name', '%$searchQuery%');
        taxiQuery = taxiQuery.ilike('profiles.full_name', '%$searchQuery%');
      }

      int fetchLimit = (searchQuery.isNotEmpty && searchType == 'رقم الرحلة') ? 1000 : 50;
      
      List<dynamic> combined = [];
      
      if (fetchTrips) {
        final tripsResponse = await tripsQuery.order('created_at', ascending: false).limit(fetchLimit);
        for(var t in tripsResponse) {
            final m = Map<String,dynamic>.from(t);
            if (m['trip_type'] == null) m['trip_type'] = 'intercity';
            combined.add(m);
        }
      }
      
      if (fetchTaxi) {
        final taxiResponse = await taxiQuery.order('created_at', ascending: false).limit(fetchLimit);
        for(var t in taxiResponse) {
            final m = Map<String,dynamic>.from(t);
            m['trip_type'] = 'taxi';
            combined.add(m);
        }
      }

      // Local Filter for Trip ID
      if (searchQuery.isNotEmpty && searchType == 'رقم الرحلة') {
        final queryStr = searchQuery.toLowerCase();
        combined = combined.where((trip) {
          final id = trip['id']?.toString().toLowerCase() ?? '';
          return id.contains(queryStr);
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
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سجل الرحلات المكتملة والملغاة', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                          items: tripTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
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
                    : ListView.builder(
                        itemCount: trips.length,
                        itemBuilder: (context, index) {
                          final trip = trips[index];
                          final status = trip['status'] ?? 'unknown';
                          final tripType = trip['trip_type'] ?? trip['type'] ?? 'غير محدد';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                // Show details
                              },
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
                                                'الكابتن: ${trip['profiles']?['full_name'] ?? 'غير معروف'}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(status),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  _translateStatus(status),
                                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                                ),
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
                                              Text('السعر: ${trip['price_per_seat'] ?? trip['total_price'] ?? 0} د.ع', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
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
        ],
      ),
    );
  }
}
