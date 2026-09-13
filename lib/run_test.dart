import 'package:supabase/supabase.dart';

void main() async {
  print('Initializing Supabase...');
  final supabase = SupabaseClient(
    'https://lvyqpyqkutdycdldoebw.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx2eXFweXFrdXRkeWNkbGRvZWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg0ODkxNDYsImV4cCI6MjA4NDA2NTE0Nn0.CiCTIvGCf9fmukndKnxnzot8CIfzKc9UQPcDXaCTANM',
  );
  
  try {
    final tripsCount = await supabase
        .from('trips')
        .select('id')
        .eq('status', 'completed');
    print('Trips table completed count: ' + tripsCount.length.toString());
  } catch (e) {
    print('Trips count failed: ' + e.toString());
  }

  try {
    final taxiCount = await supabase
        .from('taxi_requests')
        .select('id')
        .eq('status', 'completed');
    print('Taxi_requests table completed count: ' + taxiCount.length.toString());
  } catch (e) {
    print('Taxi requests count failed: ' + e.toString());
  }
}
