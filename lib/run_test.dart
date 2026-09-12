import 'package:supabase/supabase.dart';

void main() async {
  print('Initializing Supabase...');
  final supabase = SupabaseClient(
    'https://lvyqpyqkutdycdldoebw.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx2eXFweXFrdXRkeWNkbGRvZWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg0ODkxNDYsImV4cCI6MjA4NDA2NTE0Nn0.CiCTIvGCf9fmukndKnxnzot8CIfzKc9UQPcDXaCTANM',
  );
  
  print('Testing count query...');
  try {
    final count = await supabase
        .from('trips')
        .select('id')
        .eq('status', 'completed')
        .count(CountOption.exact);
    print('Count query successful, result type: ${count.runtimeType}, value: $count');
  } catch (e) {
    print('Count query failed: $e');
  }
  
  print('Testing history query...');
  try {
    var query = supabase.from('trips').select('*, profiles!driver_id(full_name)');
    // No filters for now
    final response = await query.order('created_at', ascending: false).limit(50);
    print('History query successful, retrieved ${response.length} items');
  } catch (e) {
    print('History query failed: $e');
  }
}
