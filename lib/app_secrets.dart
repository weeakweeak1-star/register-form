import 'env/env.dart';

/// AppSecrets provides secure access to environment variables obfuscated via Envied.
class AppSecrets {
  static String get supabaseUrl => Env.supabaseUrl;
  static String get supabaseAnonKey => Env.supabaseAnonKey;
  static String get googleMapsApiKey => Env.googleMapsApiKey;
  static String? get whatsappApiKey => Env.whatsappApiKey;
  static String? get whatsappPhoneNumberId => Env.whatsappPhoneNumberId;
}
