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
  List<Map<String, dynamic>> _trips = [];

  @override
  void initState() {
    super.initState();
    _fetchTrips();
  }

  Future<void> _fetchTrips() async {
    try {
      // First try to fetch from 'trips' (intercity)
      final tripsData = await _supabase
          .from('trips')
          .select()
          .eq('driver_id', widget.driverId)
          .order('created_at', ascending: false)
          .limit(50);
          
      // Next, we might want to fetch taxi_requests too if they are separate.
      // For simplicity, we just show trips here. If the schema combines them, great.
          
      setState(() {
        _trips = List<Map<String, dynamic>>.from(tripsData);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching trips: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('رحلات الكابتن: ${widget.driverName}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: _trips.isEmpty
                    ? const Center(child: Text('لا توجد رحلات (مشتركة / خارجية) لهذا الكابتن حتى الآن'))
                    : ListView.separated(
                        itemCount: _trips.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final trip = _trips[index];
                          final status = trip['status'] ?? 'unknown';
                          
                          Color statusColor = Colors.grey;
                          String statusText = status;
                          if (status == 'completed') { statusColor = Colors.green; statusText = 'مكتملة'; }
                          else if (status == 'ongoing' || status == 'started') { statusColor = Colors.blue; statusText = 'جارية'; }
                          else if (status == 'cancelled') { statusColor = Colors.red; statusText = 'ملغاة'; }

                          return ListTile(
                            title: Text('رحلة رقم: ${trip['id'].toString().substring(0, 8)}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('السعر: ${trip['price_per_seat'] ?? 0} د.ع / مقعد'),
                                Text('التاريخ: ${trip['departure_time']?.toString().split('T').first ?? 'غير محدد'}'),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                            isThreeLine: true,
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
