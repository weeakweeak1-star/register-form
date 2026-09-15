import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/app_secrets.dart';

void main() async {
  print('Initializing Supabase...');
  await Supabase.initialize(
    url: AppSecrets.supabaseUrl,
    anonKey: AppSecrets.supabaseAnonKey,
  );
  
  final supabase = Supabase.instance.client;
  print('Fetching trip c58066b0-f192-451a-bc5f-c3a39b28ad6f...');
  
  try {
    final response = await supabase.from('trips').select().eq('id', 'c58066b0-f192-451a-bc5f-c3a39b28ad6f');
    print('Trip data: $response');
  } catch (e) {
    print('Error fetching trip: $e');
  }
}
