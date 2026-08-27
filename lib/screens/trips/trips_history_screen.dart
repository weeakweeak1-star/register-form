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
  }

  Future<void> _fetchHistory() async {
    try {
      final response = await supabase
          .from('trips')
          .select('*, profiles!driver_id(full_name)')
          .neq('status', 'ongoing')
          .order('created_at', ascending: false)
          .limit(50);
      setState(() {
        trips = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سجل الرحلات المكتملة والملغاة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : trips.isEmpty
                    ? const Center(child: Text('لا توجد بيانات'))
                    : ListView.builder(
                        itemCount: trips.length,
                        itemBuilder: (context, index) {
                          final trip = trips[index];
                          final status = trip['status'] ?? 'unknown';
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                status == 'completed' ? Icons.check_circle : Icons.cancel,
                                color: status == 'completed' ? Colors.green : Colors.red,
                              ),
                              title: Text('الكابتن: ${trip['profiles']?['full_name'] ?? 'غير معروف'}'),
                              subtitle: Text('التاريخ: ${_formatDate(trip['created_at'])} | سعر المقعد: ${trip['price_per_seat']} د.ع'),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                // TODO: Show trip details
                              },
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
