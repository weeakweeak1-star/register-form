import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env', obfuscate: true)
abstract class Env {
  @EnviedField(varName: 'SUPABASE_URL', obfuscate: true)
  static final String supabaseUrl = _Env.supabaseUrl;

  @EnviedField(varName: 'SUPABASE_ANON_KEY', obfuscate: true)
  static final String supabaseAnonKey = _Env.supabaseAnonKey;

  @EnviedField(varName: 'GOOGLE_MAPS_API_KEY', obfuscate: true)
  static final String googleMapsApiKey = _Env.googleMapsApiKey;

  @EnviedField(varName: 'WHATSAPP_API_KEY', obfuscate: true, optional: true)
  static final String? whatsappApiKey = _Env.whatsappApiKey;

  @EnviedField(varName: 'WHATSAPP_PHONE_NUMBER_ID', obfuscate: true, optional: true)
  static final String? whatsappPhoneNumberId = _Env.whatsappPhoneNumberId;
}
