-- ==============================================================================
-- Migration: Add updated_at to Profiles & Fix Full Captain Approval Flow
-- ==============================================================================

-- 1. إضافة عمود updated_at الناقص إلى جدول profiles مع تعيين قيمته الافتراضية
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::TEXT, now());

-- تعيين القيمة لجميع الحسابات الحالية التي قد تحتوي على NULL
UPDATE public.profiles
SET updated_at = timezone('utc'::TEXT, now())
WHERE updated_at IS NULL;

-- التأكد من وجود created_at أيضاً
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::TEXT, now());

-- التأكد من وجود كافة أعمدة المستمسكات والمركبة في profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS phone_number TEXT,
  ADD COLUMN IF NOT EXISTS profile_picture_url TEXT,
  ADD COLUMN IF NOT EXISTS id_card_front_url TEXT,
  ADD COLUMN IF NOT EXISTS id_card_back_url TEXT,
  ADD COLUMN IF NOT EXISTS car_reg_front_url TEXT,
  ADD COLUMN IF NOT EXISTS car_reg_back_url TEXT,
  ADD COLUMN IF NOT EXISTS license_url TEXT,
  ADD COLUMN IF NOT EXISTS power_of_attorney_url TEXT,
  ADD COLUMN IF NOT EXISTS car_type TEXT,
  ADD COLUMN IF NOT EXISTS car_model TEXT,
  ADD COLUMN IF NOT EXISTS car_color TEXT,
  ADD COLUMN IF NOT EXISTS car_plate TEXT,
  ADD COLUMN IF NOT EXISTS car_seats INTEGER DEFAULT 4,
  ADD COLUMN IF NOT EXISTS is_driver BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS driver_status TEXT DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS reject_reason TEXT;

-- 2. إنشاء فهارس على حقول أرقام الهواتف لتسريع عمليات المطابقة والتحقق
CREATE INDEX IF NOT EXISTS idx_profiles_phone_number ON public.profiles (phone_number);
CREATE INDEX IF NOT EXISTS idx_profiles_updated_at ON public.profiles (updated_at);
CREATE INDEX IF NOT EXISTS idx_driver_applications_phone_number ON public.driver_applications (phone_number);

-- 3. إنشاء جدول المحافظ driver_wallets في حال عدم وجوده
CREATE TABLE IF NOT EXISTS public.driver_wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE UNIQUE NOT NULL,
    balance NUMERIC(12, 2) DEFAULT 0.00 NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::TEXT, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::TEXT, now()) NOT NULL
);

-- تفعيل RLS على driver_wallets
ALTER TABLE public.driver_wallets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Drivers can view their own wallet." ON public.driver_wallets;
CREATE POLICY "Drivers can view their own wallet." ON public.driver_wallets 
  FOR SELECT USING (auth.uid() = driver_id);

-- 4. دالة وتريجر لتحديث updated_at تلقائياً في profiles عند أي تعديل
CREATE OR REPLACE FUNCTION public.handle_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::TEXT, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_profiles_updated_at ON public.profiles;
CREATE TRIGGER tr_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE PROCEDURE public.handle_profiles_updated_at();

-- 5. الدالة الشاملة لمزامنة طلبات الكباتن driver_applications إلى profiles و auth.users
CREATE OR REPLACE FUNCTION public.sync_approved_application_to_profile()
RETURNS TRIGGER AS $$
DECLARE
  v_digits TEXT;
  v_e164_phone TEXT;
  v_user_id UUID;
  v_existing_profile_id UUID;
  v_existing_auth_id UUID;
BEGIN
  -- أ. تنظيف واستخلاص آخر 10 أرقام من الهاتف (لتجاوز +964 أو 07 أو أي مسافات)
  v_digits := RIGHT(regexp_replace(NEW.phone_number, '\D', '', 'g'), 10);
  
  IF v_digits IS NULL OR length(v_digits) < 9 THEN
    v_digits := NEW.phone_number;
    v_e164_phone := NEW.phone_number;
  ELSE
    v_e164_phone := '+964' || v_digits;
  END IF;

  -- ============================================================================
  -- الحالة الأولى: عند الموافقة على الطلب (Approved)
  -- ============================================================================
  IF NEW.status = 'approved' THEN

    -- البحث عن معرف المستخدم في جدول profiles أولاً
    SELECT id INTO v_existing_profile_id
    FROM public.profiles
    WHERE RIGHT(regexp_replace(phone, '\D', '', 'g'), 10) = v_digits
       OR (phone_number IS NOT NULL AND RIGHT(regexp_replace(phone_number, '\D', '', 'g'), 10) = v_digits)
    ORDER BY created_at DESC
    LIMIT 1;

    -- البحث عن معرف المستخدم في جدول auth.users
    SELECT id INTO v_existing_auth_id
    FROM auth.users
    WHERE RIGHT(regexp_replace(phone, '\D', '', 'g'), 10) = v_digits
    ORDER BY created_at DESC
    LIMIT 1;

    -- تحديد الـ ID المستهدف
    v_user_id := COALESCE(v_existing_profile_id, v_existing_auth_id);

    -- إذا لم يكن للمستخدم أي حساب في auth.users، يتم إنشاؤه فوراً
    IF v_existing_auth_id IS NULL THEN
      IF v_user_id IS NULL THEN
        v_user_id := gen_random_uuid();
      END IF;

      INSERT INTO auth.users (
        id,
        instance_id,
        aud,
        role,
        phone,
        phone_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at
      ) VALUES (
        v_user_id,
        '00000000-0000-0000-0000-000000000000'::uuid,
        'authenticated',
        'authenticated',
        v_e164_phone,
        now(),
        jsonb_build_object(
          'provider', 'phone',
          'providers', jsonb_build_array('phone'),
          'role', 'captain',
          'driver_status', 'approved'
        ),
        jsonb_build_object(
          'full_name', NEW.full_name,
          'phone', v_e164_phone,
          'phone_number', NEW.phone_number,
          'is_driver', true,
          'driver_status', 'approved'
        ),
        now(),
        now()
      );

      -- إنشاء الهوية في auth.identities
      BEGIN
        INSERT INTO auth.identities (
          id,
          user_id,
          identity_data,
          provider,
          last_sign_in_at,
          created_at,
          updated_at
        ) VALUES (
          v_user_id::text,
          v_user_id,
          jsonb_build_object('sub', v_user_id::text, 'phone', v_e164_phone),
          'phone',
          now(),
          now(),
          now()
        ) ON CONFLICT DO NOTHING;
      EXCEPTION WHEN OTHERS THEN
        -- تجاهل الخطأ في حال وجود قيود إضافية على identities
      END;

    ELSE
      -- إذا كان حسابه موجوداً بالفعل في auth.users: ترقية الرتبة إلى captain وحالة الاعتماد
      UPDATE auth.users
      SET 
        phone = COALESCE(phone, v_e164_phone),
        phone_confirmed_at = COALESCE(phone_confirmed_at, now()),
        raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb) || 
          jsonb_build_object(
            'role', 'captain',
            'driver_status', 'approved'
          ),
        raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) ||
          jsonb_build_object(
            'full_name', NEW.full_name,
            'phone', v_e164_phone,
            'phone_number', NEW.phone_number,
            'is_driver', true,
            'driver_status', 'approved'
          ),
        updated_at = now()
      WHERE id = v_user_id;
    END IF;

    -- نقل البيانات الشامل وإدراج/تحديث سجل الكابتن في public.profiles (UPSERT)
    INSERT INTO public.profiles (
      id,
      full_name,
      phone,
      phone_number,
      avatar_url,
      profile_picture_url,
      id_card_front_url,
      id_card_back_url,
      car_reg_front_url,
      car_reg_back_url,
      license_url,
      power_of_attorney_url,
      car_type,
      car_model,
      car_color,
      car_plate,
      car_seats,
      is_driver,
      driver_status,
      created_at,
      updated_at
    ) VALUES (
      v_user_id,
      NEW.full_name,
      v_e164_phone,
      NEW.phone_number,
      COALESCE(NEW.profile_picture_url, ''),
      NEW.profile_picture_url,
      NEW.id_card_front_url,
      NEW.id_card_back_url,
      NEW.car_reg_front_url,
      NEW.car_reg_back_url,
      NEW.license_url,
      NEW.power_of_attorney_url,
      NEW.car_type,
      NEW.car_model,
      NEW.car_color,
      NEW.car_plate,
      COALESCE(NEW.car_seats, 4),
      true,
      'approved',
      now(),
      now()
    )
    ON CONFLICT (id) DO UPDATE SET
      full_name = EXCLUDED.full_name,
      phone = COALESCE(public.profiles.phone, EXCLUDED.phone),
      phone_number = EXCLUDED.phone_number,
      avatar_url = COALESCE(EXCLUDED.avatar_url, public.profiles.avatar_url),
      profile_picture_url = EXCLUDED.profile_picture_url,
      id_card_front_url = EXCLUDED.id_card_front_url,
      id_card_back_url = EXCLUDED.id_card_back_url,
      car_reg_front_url = EXCLUDED.car_reg_front_url,
      car_reg_back_url = EXCLUDED.car_reg_back_url,
      license_url = EXCLUDED.license_url,
      power_of_attorney_url = EXCLUDED.power_of_attorney_url,
      car_type = COALESCE(EXCLUDED.car_type, public.profiles.car_type),
      car_model = COALESCE(EXCLUDED.car_model, public.profiles.car_model),
      car_color = COALESCE(EXCLUDED.car_color, public.profiles.car_color),
      car_plate = COALESCE(EXCLUDED.car_plate, public.profiles.car_plate),
      car_seats = COALESCE(EXCLUDED.car_seats, public.profiles.car_seats),
      is_driver = true,
      driver_status = 'approved',
      updated_at = now();

    -- إنشاء المحفظة المالية للكابتن تلقائياً إن لم تكن موجودة
    BEGIN
      INSERT INTO public.driver_wallets (driver_id, balance, created_at, updated_at)
      VALUES (v_user_id, 0.00, now(), now())
      ON CONFLICT (driver_id) DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
      -- تجاوز أي خطأ فرعي
    END;

  -- ============================================================================
  -- الحالة الثانية: عند الرفض أو إلغاء التفعيل (Rejected / Suspended)
  -- ============================================================================
  ELSIF NEW.status IN ('rejected', 'suspended') AND (OLD IS NULL OR OLD.status != NEW.status) THEN
    
    UPDATE public.profiles
    SET 
      driver_status = NEW.status,
      is_driver = false,
      reject_reason = NEW.reject_reason,
      updated_at = now()
    WHERE RIGHT(regexp_replace(phone, '\D', '', 'g'), 10) = v_digits
       OR (phone_number IS NOT NULL AND RIGHT(regexp_replace(phone_number, '\D', '', 'g'), 10) = v_digits);

    UPDATE auth.users
    SET 
      raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb) || 
        jsonb_build_object(
          'role', 'passenger',
          'driver_status', NEW.status
        ),
      updated_at = now()
    WHERE RIGHT(regexp_replace(phone, '\D', '', 'g'), 10) = v_digits;

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- 6. إعادة ربط الـ Trigger بجدول driver_applications
DROP TRIGGER IF EXISTS tr_sync_approved_application_to_profile ON public.driver_applications;
CREATE TRIGGER tr_sync_approved_application_to_profile
  AFTER INSERT OR UPDATE ON public.driver_applications
  FOR EACH ROW
  EXECUTE PROCEDURE public.sync_approved_application_to_profile();

-- 7. تحديث تريجر handle_approved_driver في profiles
CREATE OR REPLACE FUNCTION public.handle_approved_driver()
RETURNS TRIGGER AS $$
DECLARE
  app_record RECORD;
BEGIN
  -- مطابقة برقم الهاتف عبر آخر 10 أرقام
  SELECT * INTO app_record FROM public.driver_applications 
  WHERE RIGHT(regexp_replace(phone_number, '\D', '', 'g'), 10) = RIGHT(regexp_replace(COALESCE(NEW.phone, NEW.phone_number), '\D', '', 'g'), 10)
  ORDER BY created_at DESC LIMIT 1;
  
  IF FOUND THEN
    IF app_record.status = 'approved' THEN
      NEW.is_driver := true;
      NEW.driver_status := 'approved';
      NEW.full_name := COALESCE(app_record.full_name, NEW.full_name);
      NEW.phone_number := COALESCE(NEW.phone_number, app_record.phone_number);
      NEW.profile_picture_url := COALESCE(app_record.profile_picture_url, NEW.profile_picture_url);
      NEW.id_card_front_url := COALESCE(app_record.id_card_front_url, NEW.id_card_front_url);
      NEW.id_card_back_url := COALESCE(app_record.id_card_back_url, NEW.id_card_back_url);
      NEW.car_reg_front_url := COALESCE(app_record.car_reg_front_url, NEW.car_reg_front_url);
      NEW.car_reg_back_url := COALESCE(app_record.car_reg_back_url, NEW.car_reg_back_url);
      NEW.license_url := COALESCE(app_record.license_url, NEW.license_url);
      NEW.power_of_attorney_url := COALESCE(app_record.power_of_attorney_url, NEW.power_of_attorney_url);
      NEW.car_type := COALESCE(app_record.car_type, NEW.car_type);
      NEW.car_model := COALESCE(app_record.car_model, NEW.car_model);
      NEW.car_color := COALESCE(app_record.car_color, NEW.car_color);
      NEW.car_plate := COALESCE(app_record.car_plate, NEW.car_plate);
      NEW.car_seats := COALESCE(app_record.car_seats, NEW.car_seats);
    ELSIF app_record.status = 'pending' THEN
      NEW.driver_status := 'pending';
    ELSIF app_record.status = 'rejected' THEN
      NEW.driver_status := 'rejected';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;
