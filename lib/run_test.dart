import 'package:supabase/supabase.dart';
import 'env/env.dart';

void main() async {
  print('Initializing Supabase...');
  final supabase = SupabaseClient(
    Env.supabaseUrl,
    Env.supabaseAnonKey,
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
