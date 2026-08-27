-- ==============================================================================
-- Migration: Add UNIQUE Constraint on Phone Column in public.profiles
-- ==============================================================================

-- 1. تنظيف الأرقام المكررة السابقة إن وُجدت (الاحتفاظ بالحساب الأحدث وتفريغ الأقدم منعاً لانهيار القيد)
WITH duplicates AS (
  SELECT id,
         ROW_NUMBER() OVER (PARTITION BY phone ORDER BY created_at DESC) as rn
  FROM public.profiles
  WHERE phone IS NOT NULL AND trim(phone) != ''
)
UPDATE public.profiles
SET phone = NULL
WHERE id IN (
  SELECT id FROM duplicates WHERE rn > 1
);

-- 2. إزالة أي قيد سابق بنفس الاسم لتجنب أخطاء تكرار التشغيل (Idempotency)
ALTER TABLE public.profiles 
DROP CONSTRAINT IF EXISTS profiles_phone_key;

-- 3. إضافة قيد UNIQUE على عمود phone
-- ملاحظة: في PostgreSQL يسمح قيد UNIQUE بتعدد القيم الفارغة NULL، 
-- ولكن يمنع نهائياً تكرار أي رقم هاتف فعلي بين أكثر من مستخدم.
ALTER TABLE public.profiles
ADD CONSTRAINT profiles_phone_key UNIQUE (phone);

-- 4. إنشاء فهرس لتسريع عمليات البحث والتحقق من وجود المستخدم عبر رقم الهاتف
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON public.profiles (phone);

-- 5. تحديث دالة الـ Trigger لضمان معالجة الأرقام الفارغة كـ NULL وليس نص فارغ ''
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_phone TEXT;
BEGIN
  v_phone := COALESCE(new.phone, new.raw_user_meta_data->>'phone', new.raw_user_meta_data->>'phone_number');
  
  -- تحويل النصوص الفارغة أو المسافات إلى NULL لضمان عدم تعارض قيد UNIQUE
  IF v_phone IS NOT NULL AND trim(v_phone) = '' THEN
    v_phone := NULL;
  END IF;

  INSERT INTO public.profiles (id, email, full_name, phone, avatar_url, is_driver)
  VALUES (
    new.id, 
    new.email, 
    new.raw_user_meta_data->>'full_name', 
    v_phone,
    new.raw_user_meta_data->>'avatar_url',
    COALESCE((new.raw_user_meta_data->>'is_driver')::BOOLEAN, FALSE)
  )
  ON CONFLICT (id) DO UPDATE SET
    phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
    email = COALESCE(EXCLUDED.email, public.profiles.email),
    full_name = COALESCE(EXCLUDED.full_name, public.profiles.full_name);
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
