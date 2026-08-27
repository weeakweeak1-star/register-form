import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverTripsModal extends StatefulWidget {
  final String driverId;
  final String driverName;

  const DriverTripsModal({super.key, required this.driverId, required this.driverName});

  @override
  State<DriverTripsModal> createState() => _DriverTripsModalState();
}

class _DriverTripsModalState extends State<DriverTripsModal> {
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

    // Fetch Intercity Trips
    try {
      final tripsData = await _supabase
          .from('trips')
          .select()
          .eq('driver_id', widget.driverId)
          .order('created_at', ascending: false)
          .limit(50);
          
      for (var t in tripsData) {
        final map = Map<String, dynamic>.from(t);
        map['is_taxi'] = false;
        combined.add(map);
      }
    } catch (e) {
      debugPrint('Error fetching trips: $e');
    }
        
    // Fetch Taxi Requests
    try {
      final taxiData = await _supabase
          .from('taxi_requests')
          .select()
          .eq('driver_id', widget.driverId)
          .order('created_at', ascending: false)
          .limit(50);
          
      for (var t in taxiData) {
        final map = Map<String, dynamic>.from(t);
        map['is_taxi'] = true;
        combined.add(map);
      }
    } catch (e) {
      debugPrint('Error fetching taxi requests: $e');
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
      debugPrint('Error sorting trips: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTripCard(Map<String, dynamic> trip, bool isTaxi) {
    final status = trip['status'] ?? 'unknown';
    Color statusColor = Colors.grey;
    String statusText = status;
    if (status == 'completed') { statusColor = Colors.green; statusText = 'مكتملة'; }
    else if (status == 'ongoing' || status == 'started' || status == 'accepted') { statusColor = Colors.blue; statusText = 'جارية'; }
    else if (status == 'cancelled' || status == 'rejected') { statusColor = Colors.red; statusText = 'ملغاة'; }

    final date = trip['created_at']?.toString().split('T').first ?? 'غير محدد';
    final timeStr = trip['created_at']?.toString().split('T').last ?? '';
    final time = timeStr.length >= 5 ? timeStr.substring(0, 5) : timeStr;
    final price = isTaxi ? (trip['estimated_price'] ?? trip['total_price'] ?? 0) : (trip['price_per_seat'] ?? 0);
    
    // Addresses
    String pickup = isTaxi ? (trip['pickup_address'] ?? 'غير محدد') : (trip['from_city'] ?? 'غير محدد');
    String dropoff = isTaxi ? (trip['dropoff_address'] ?? 'غير محدد') : (trip['to_city'] ?? 'غير محدد');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
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
                    Icon(isTaxi ? Icons.local_taxi : Icons.directions_bus, color: isTaxi ? Colors.orange : Colors.indigo),
                    const SizedBox(width: 8),
                    Text(isTaxi ? 'تكسي داخلي' : 'رحلة خارجية', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.my_location, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(child: Text('من: $pickup', style: const TextStyle(fontSize: 14))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text('إلى: $dropoff', style: const TextStyle(fontSize: 14))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('$date  $time', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                Text('السعر: $price د.ع', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
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
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('سجل رحلات الكابتن: ${widget.driverName}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: _allTrips.isEmpty
                    ? const Center(child: Text('لا توجد رحلات مسجلة لهذا الكابتن حتى الآن', style: TextStyle(fontSize: 16)))
                    : ListView.builder(
                        itemCount: _allTrips.length,
                        itemBuilder: (context, index) {
                          final trip = _allTrips[index];
                          return _buildTripCard(trip, trip['is_taxi'] == true);
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
