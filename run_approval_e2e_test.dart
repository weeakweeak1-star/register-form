import 'dart:convert';
import 'dart:io';
import 'lib/env/env.dart';

void main() async {
  final client = HttpClient();
  try {
    print('===============================================================');
    print('🚀 بدء اختبار محاكاة اعتماد الكابتن الشامل (End-to-End Test)');
    print('===============================================================\n');

    // 1. تسجيل مستخدم والحصول على JWT authenticated
    print('🔑 [الخطوة 1]: توليد جلسة مصادقة (Authenticated Session)...');
    final authEmail = 'e2e_tester_${DateTime.now().millisecondsSinceEpoch}@example.com';
    final signupUri = Uri.parse('${Env.supabaseUrl}/auth/v1/signup');
    final signupReq = await client.postUrl(signupUri);
    signupReq.headers.add('apikey', Env.supabaseAnonKey);
    signupReq.headers.add('Authorization', 'Bearer ${Env.supabaseAnonKey}');
    signupReq.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
    signupReq.add(utf8.encode(jsonEncode({
      'email': authEmail,
      'password': 'StrongPassword123!',
    })));
    final signupRes = await signupReq.close();
    final signupBody = await signupRes.transform(utf8.decoder).join();
    final signupData = jsonDecode(signupBody);
    final token = signupData['access_token'];

    if (token == null) {
      print('❌ فشل الحصول على جلسة المصادقة: $signupBody');
      return;
    }
    print('✅ تم تسجيل الدخول بنجاح بصلاحية authenticated.\n');

    // 2. التحقق المسبق من وجود عمود updated_at في profiles
    print('🔍 [الخطوة 2]: فحص بنية جدول profiles والتحقق من عمود updated_at...');
    final profileCheckUri = Uri.parse('${Env.supabaseUrl}/rest/v1/profiles?select=id,updated_at&limit=1');
    final profileCheckReq = await client.getUrl(profileCheckUri);
    profileCheckReq.headers.add('apikey', Env.supabaseAnonKey);
    profileCheckReq.headers.add('Authorization', 'Bearer $token');
    final profileCheckRes = await profileCheckReq.close();
    final profileCheckBody = await profileCheckRes.transform(utf8.decoder).join();

    if (profileCheckRes.statusCode != 200) {
      print('⚠️ تنبيه: جدول profiles لا يزال يفتقد عمود updated_at!');
      print('   الرد من قاعدة البيانات: $profileCheckBody\n');
    } else {
      print('✅ عمود updated_at موجود بنجاح في جدول profiles.\n');
    }

    // 3. إنشاء طلب كابتن وهمي في driver_applications
    final testDigits = (1000000 + DateTime.now().millisecondsSinceEpoch % 9000000).toString();
    final testPhone = '0770$testDigits';
    final expectedE164 = '+964770$testDigits';
    final testName = 'كابتن فحص مؤتمت $testDigits';

    print('📝 [الخطوة 3]: إدراج طلب انضمام وهمي في جدول driver_applications...');
    print('   - الاسم: $testName');
    print('   - رقم الهاتف: $testPhone (المتوقع دولياً: $expectedE164)');

    final insertUri = Uri.parse('${Env.supabaseUrl}/rest/v1/driver_applications');
    final insertReq = await client.postUrl(insertUri);
    insertReq.headers.add('apikey', Env.supabaseAnonKey);
    insertReq.headers.add('Authorization', 'Bearer $token');
    insertReq.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
    insertReq.headers.add('Prefer', 'return=representation');
    insertReq.add(utf8.encode(jsonEncode({
      'full_name': testName,
      'phone_number': testPhone,
      'profile_picture_url': 'https://storage.supabase.co/driver_documents/test_pfp.jpg',
      'id_card_front_url': 'https://storage.supabase.co/driver_documents/test_id_front.jpg',
      'id_card_back_url': 'https://storage.supabase.co/driver_documents/test_id_back.jpg',
      'car_reg_front_url': 'https://storage.supabase.co/driver_documents/test_reg_front.jpg',
      'car_reg_back_url': 'https://storage.supabase.co/driver_documents/test_reg_back.jpg',
      'license_url': 'https://storage.supabase.co/driver_documents/test_license.jpg',
      'power_of_attorney_url': 'https://storage.supabase.co/driver_documents/test_poa.jpg',
      'status': 'pending',
    })));
    final insertRes = await insertReq.close();
    final insertBody = await insertRes.transform(utf8.decoder).join();

    if (insertRes.statusCode >= 300) {
      print('❌ فشل إدراج الطلب في driver_applications:');
      print('   كود الحالة: ${insertRes.statusCode}');
      print('   الخطأ: $insertBody');
      return;
    }

    final insertedApps = jsonDecode(insertBody) as List;
    final appId = insertedApps.first['id'];
    print('✅ تم إدراج الطلب بنجاح بـ المعرف (Application ID): $appId\n');

    // 4. محاكاة ضغط موظف الإدارة على زر "موافقة" (Approve)
    print('⚙️ [الخطوة 4]: محاكاة عملية الموافقة عبر تطبيق الإدارة...');
    print('   - تحديث الحالة إلى: approved');
    print('   - تعبئة بيانات المركبة: تايوتا كامري / بغداد 12345 / 4 مقاعد');

    final approveUri = Uri.parse('${Env.supabaseUrl}/rest/v1/driver_applications?id=eq.$appId');
    final approveReq = await client.patchUrl(approveUri);
    approveReq.headers.add('apikey', Env.supabaseAnonKey);
    approveReq.headers.add('Authorization', 'Bearer $token');
    approveReq.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
    approveReq.headers.add('Prefer', 'return=representation');
    approveReq.add(utf8.encode(jsonEncode({
      'status': 'approved',
      'car_type': 'تايوتا',
      'car_model': 'كامري 2023',
      'car_color': 'فضي',
      'car_plate': '12345 - أ - بغداد',
      'car_seats': 4,
    })));
    final approveRes = await approveReq.close();
    final approveBody = await approveRes.transform(utf8.decoder).join();

    if (approveRes.statusCode >= 300) {
      print('❌ فشلت عملية الموافقة! الخطأ الناتج:');
      print('   كود الاستجابة: ${approveRes.statusCode}');
      print('   تفاصيل الخطأ: $approveBody\n');
      return;
    }

    print('✅ تم إرسال أمر الموافقة بنجاح واستجاب الخادم بكود 200/204!\n');

    // 5. التحقق من تدفق البيانات (Data Flow Validation)
    print('📊 [الخطوة 5]: تتبع تدفق البيانات (Data Flow Validation)...');

    // أ. فحص جدول profiles
    final encodedPhone = Uri.encodeComponent(expectedE164);
    final profileQueryUri = Uri.parse('${Env.supabaseUrl}/rest/v1/profiles?phone=eq.$encodedPhone');
    final profileQueryReq = await client.getUrl(profileQueryUri);
    profileQueryReq.headers.add('apikey', Env.supabaseAnonKey);
    profileQueryReq.headers.add('Authorization', 'Bearer $token');
    final profileQueryRes = await profileQueryReq.close();
    final profileQueryBody = await profileQueryRes.transform(utf8.decoder).join();

    if (profileQueryRes.statusCode == 200) {
      final profilesList = jsonDecode(profileQueryBody) as List;
      if (profilesList.isNotEmpty) {
        final profile = profilesList.first as Map<String, dynamic>;
        print('✅ [1. فحص جدول profiles]:');
        print('   - المعرف (User ID): ${profile['id']}');
        print('   - الاسم الكامل: ${profile['full_name']}');
        print('   - رقم الهاتف: ${profile['phone']}');
        print('   - هل تم تفعيل الكابتن (is_driver): ${profile['is_driver']}');
        print('   - حالة الكابتن (driver_status): ${profile['driver_status']}');
        print('   - بيانات المركبة: ${profile['car_type']} ${profile['car_model']} (${profile['car_plate']}) - مقاعد: ${profile['car_seats']}');
        print('   - صورة البروفايل: ${profile['profile_picture_url'] != null ? "مكتملة ✓" : "فارغة"}');
        print('   - إجازة السوق: ${profile['license_url'] != null ? "مكتملة ✓" : "فارغة"}');
        print('   - هوية الأحوال (وجه وظهر): ${profile['id_card_front_url'] != null && profile['id_card_back_url'] != null ? "مكتملة ✓" : "ناقصة"}');
        print('   - السنوية (وجه وظهر): ${profile['car_reg_front_url'] != null && profile['car_reg_back_url'] != null ? "مكتملة ✓" : "ناقصة"}');
        print('   - وقت التحديث (updated_at): ${profile['updated_at']}');

        // ب. فحص المحفظة المالية
        final walletUri = Uri.parse('${Env.supabaseUrl}/rest/v1/driver_wallets?driver_id=eq.${profile['id']}');
        final walletReq = await client.getUrl(walletUri);
        walletReq.headers.add('apikey', Env.supabaseAnonKey);
        walletReq.headers.add('Authorization', 'Bearer $token');
        final walletRes = await walletReq.close();
        final walletBody = await walletRes.transform(utf8.decoder).join();
        if (walletRes.statusCode == 200) {
          final wallets = jsonDecode(walletBody) as List;
          print('\n✅ [2. فحص المحفظة driver_wallets]:');
          if (wallets.isNotEmpty) {
            print('   - تم إنشاء المحفظة بنجاح، الرصيد الابتدائي: ${wallets.first['balance']} د.ع');
          } else {
            print('   - المحفظة لم تُنشأ بعد (أو سياسة RLS تحجب قراءتها لغير صاحبها).');
          }
        }
      } else {
        print('❌ لم يتم العثور على سجل للكابتن برقم الهاتف $expectedE164 في جدول profiles!');
      }
    } else {
      print('❌ خطأ أثناء الاستعلام عن جدول profiles: $profileQueryBody');
    }

    print('\n===============================================================');
    print('🏁 نهاية تقرير الاختبار');
    print('===============================================================');

  } catch (e, st) {
    print('❌ استثناء غير متوقع أثناء الفحص: $e\n$st');
  } finally {
    client.close(force: true);
  }
}
