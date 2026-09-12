import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> test() async {
  final supabase = Supabase.instance.client;
  
  // Test 1: count() terminal method
  final int c1 = await supabase.from('trips').count();
  
  // Test 2: count() after eq
  // final int c2 = await supabase.from('trips').eq('status', 'completed').count(); // Is this valid?
}
