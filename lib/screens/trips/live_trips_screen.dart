import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveTripsScreen extends StatefulWidget {
  const LiveTripsScreen({super.key});

  @override
  State<LiveTripsScreen> createState() => _LiveTripsScreenState();
}

class _LiveTripsScreenState extends State<LiveTripsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<dynamic> trips = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLiveTrips();
  }

  Future<void> _fetchLiveTrips() async {
    try {
      // Assuming 'status' = 'ongoing' or 'active' represents a live trip
      final response = await supabase
          .from('trips')
          .select('*, profiles!driver_id(full_name)')
          .eq('status', 'ongoing')
          .order('created_at', ascending: false);
      setState(() {
        trips = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      // Fallback for mock data if table doesn't exist yet
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الرحلات الجارية الآن', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : trips.isEmpty
                    ? const Center(child: Text('لا توجد رحلات جارية حالياً'))
                    : ListView.builder(
                        itemCount: trips.length,
                        itemBuilder: (context, index) {
                          final trip = trips[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.drive_eta, color: Colors.blue),
                              title: Text('رحلة مع الكابتن: ${trip['profiles']?['full_name'] ?? 'غير معروف'}'),
                              subtitle: Text('المسار: ${trip['origin']} -> ${trip['destination']}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.red),
                                tooltip: 'إنهاء أو إلغاء الرحلة',
                                onPressed: () {
                                  // TODO: Cancel trip logic
                                },
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
