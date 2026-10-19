import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerTripsModal extends StatefulWidget {
  final String customerId;
  final String customerName;

  const CustomerTripsModal({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<CustomerTripsModal> createState() => _CustomerTripsModalState();
}

class _CustomerTripsModalState extends State<CustomerTripsModal> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allTrips = [];

  @override
  void initState() {
    super.initState();
    _fetchTrips();
  }

  Future<void> _fetchTrips() async {
    final List<Map<String, dynamic>> combined = [];

    // 1. Fetch Taxi Requests (مشاوير التاكسي)
    try {
      final taxiData = await _supabase
          .from('taxi_requests')
          .select('*, driver:profiles!driver_id(full_name, phone)')
          .eq('passenger_id', widget.customerId)
          .order('created_at', ascending: false)
          .limit(50);

      for (var t in taxiData) {
        final map = Map<String, dynamic>.from(t);
        map['is_taxi'] = true;
        combined.add(map);
      }
    } catch (e) {
      debugPrint('Error fetching customer taxi requests: $e');
    }

    // 2. Fetch Intercity Bookings (حجوزات السفر بين المدن)
    try {
      final bookingsData = await _supabase
          .from('bookings')
          .select('*, trip:trips(*, driver:profiles!driver_id(full_name, phone))')
          .eq('passenger_id', widget.customerId)
          .order('created_at', ascending: false)
          .limit(50);

      for (var b in bookingsData) {
        final map = Map<String, dynamic>.from(b);
        map['is_taxi'] = false;
        combined.add(map);
      }
    } catch (e) {
      debugPrint('Error fetching customer bookings: $e');
    }

    try {
      // Sort by created_at descending
      combined.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at'].toString()) ?? DateTime.now();
        final dateB = DateTime.tryParse(b['created_at'].toString()) ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _allTrips = combined;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error sorting customer trips: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTripCard(Map<String, dynamic> item, bool isTaxi) {
    final status = item['status']?.toString().toLowerCase() ?? 'unknown';
    Color statusColor = Colors.grey;
    String statusText = status;

    if (status == 'completed') {
      statusColor = Colors.green;
      statusText = 'مكتملة';
    } else if (status == 'ongoing' || status == 'started' || status == 'accepted' || status == 'arrived') {
      statusColor = Colors.blue;
      statusText = 'جارية';
    } else if (status == 'cancelled' || status == 'rejected') {
      statusColor = Colors.red;
      statusText = 'ملغاة';
    } else if (status == 'pending' || status == 'scheduled' || status == 'searching') {
      statusColor = Colors.orange;
      statusText = 'قيد الانتظار';
    }

    final date = item['created_at']?.toString().split('T').first ?? 'غير محدد';
    final timeStr = item['created_at']?.toString().split('T').last ?? '';
    final time = timeStr.length >= 5 ? timeStr.substring(0, 5) : timeStr;

    num price = 0;
    String pickup = 'غير محدد';
    String dropoff = 'غير محدد';
    String? driverName;
    String? driverPhone;

    if (isTaxi) {
      price = item['price'] ?? item['estimated_price'] ?? item['total_price'] ?? 0;
      pickup = item['pickup_address'] ?? 'موقع الانطلاق';
      dropoff = item['dropoff_address'] ?? 'وجهة الوصول';
      final driver = item['driver'];
      if (driver is Map) {
        driverName = driver['full_name'];
        driverPhone = driver['phone'];
      }
    } else {
      // Intercity booking
      price = item['total_price'] ?? 0;
      final trip = item['trip'];
      if (trip is Map) {
        pickup = trip['origin'] ?? 'غير محدد';
        dropoff = trip['destination'] ?? 'غير محدد';
        final driver = trip['driver'];
        if (driver is Map) {
          driverName = driver['full_name'];
          driverPhone = driver['phone'];
        }
      }
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isTaxi ? Colors.amber.shade100 : Colors.indigo.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isTaxi ? Icons.local_taxi : Icons.directions_bus,
                            size: 16,
                            color: isTaxi ? Colors.amber.shade900 : Colors.indigo.shade900,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isTaxi ? 'مشوار تاكسي' : 'سفر بين المحافظات',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isTaxi ? Colors.amber.shade900 : Colors.indigo.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor, width: 0.5),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
                Text(
                  '$price د.ع',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.my_location, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('من: $pickup', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('إلى: $dropoff', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ),
              ],
            ),
            if (driverName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_pin, size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Text(
                    'الكابتن: $driverName ${driverPhone != null ? "($driverPhone)" : ""}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  '$date $time',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 650,
        height: 700,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_edu_rounded, color: Colors.indigo, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        'سجل رحلات: ${widget.customerName}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _allTrips.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'لا توجد رحلات أو حجوزات مسجلة لهذا الزبون',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _allTrips.length,
                          itemBuilder: (context, index) {
                            final trip = _allTrips[index];
                            final isTaxi = trip['is_taxi'] == true;
                            return _buildTripCard(trip, isTaxi);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
