import 'package:flutter_test/flutter_test.dart';
import 'package:my_weeak_admin/env/env.dart';

void main() {
  test('Env obfuscated keys decode successfully', () {
    expect(Env.supabaseUrl, isNotEmpty);
    expect(Env.supabaseUrl, startsWith('https://'));
    expect(Env.supabaseAnonKey, isNotEmpty);
    expect(Env.googleMapsApiKey, isNotEmpty);
    
    print('Env supabaseUrl decoded successfully: ${Env.supabaseUrl}');
    print('Env googleMapsApiKey starts with: ${Env.googleMapsApiKey.substring(0, 8)}...');
  });
}
