import 'dart:io';

void main() async {
  final file = File('lib/app_secrets.dart');
  final content = file.readAsStringSync();
  
  final urlMatch = RegExp(r"supabaseUrl\s*=\s*'([^']+)'").firstMatch(content);
  final keyMatch = RegExp(r"supabaseAnonKey\s*=\s*'([^']+)'").firstMatch(content);
  
  if (urlMatch != null && keyMatch != null) {
    print('URL: \');
    print('KEY: \...');
  } else {
    print('Could not find credentials');
  }
}
