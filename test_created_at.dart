import 'dart:convert';
import 'dart:io';
import 'lib/env/env.dart';

void main() async {
  final url = '${Env.supabaseUrl}/rest/v1/bookings?select=created_at&limit=1';
  final uri = Uri.parse(url);
  final request = await HttpClient().getUrl(uri);
  request.headers.add('apikey', Env.supabaseAnonKey);
  request.headers.add('Authorization', 'Bearer ${Env.supabaseAnonKey}');
  
  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();
  print('Status: ${response.statusCode}');
  print('Body: $responseBody');
}
