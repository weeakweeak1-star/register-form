import 'dart:convert';
import 'dart:io';

void main() async {
  final url = 'https://lvyqpyqkutdycdldoebw.supabase.co/rest/v1/bookings?select=created_at&limit=1';
  final uri = Uri.parse(url);
  final request = await HttpClient().getUrl(uri);
  request.headers.add('apikey', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx2eXFweXFrdXRkeWNkbGRvZWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg0ODkxNDYsImV4cCI6MjA4NDA2NTE0Nn0.CiCTIvGCf9fmukndKnxnzot8CIfzKc9UQPcDXaCTANM');
  request.headers.add('Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx2eXFweXFrdXRkeWNkbGRvZWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg0ODkxNDYsImV4cCI6MjA4NDA2NTE0Nn0.CiCTIvGCf9fmukndKnxnzot8CIfzKc9UQPcDXaCTANM');
  
  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();
  print('Status: ${response.statusCode}');
  print('Body: $responseBody');
}
