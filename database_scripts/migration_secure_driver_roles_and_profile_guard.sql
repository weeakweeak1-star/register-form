-- ==============================================================================
-- Migration: Secure Driver Roles, Claims & Profile Guard Trigger
-- ==============================================================================

-- 1. إضافة حقل حالة اعتماد السائق driver_status في profiles
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS driver_status TEXT DEFAULT 'approved' 
CHECK (driver_status IN ('none', 'pending', 'approved', 'suspended', 'rejected'));

-- 2. تريجر لحماية الحقول الحساسة في profiles من التلاعب المباشر
-- يمنع المستخدم من تعديل التقييم (rating) أو تعديل driver_status بنفسه
CREATE OR REPLACE FUNCTION public.guard_profile_sensitive_fields()
RETURNS TRIGGER AS $$
BEGIN
  -- أ. منع تعديل التقييم يدوياً من جهة العميل (يُعدل فقط عبر تريجر التقييمات tr_update_profile_rating)
  IF TG_OP = 'UPDATE' AND NEW.rating IS DISTINCT FROM OLD.rating THEN
    -- إذا كان التعديل ليس من تريجر النظام الداخلي
    IF pg_trigger_depth() <= 1 THEN
      NEW.rating := OLD.rating;
    END IF;
  END IF;

  -- ب. منع المستخدم العادي من رفع رتبة حسابه إلى معتمد (approved) بنفسه إذا كان معلقاً أو قيد المراجعة
  IF TG_OP = 'UPDATE' AND OLD.driver_status IN ('suspended', 'rejected', 'pending') AND NEW.driver_status = 'approved' THEN
    IF pg_trigger_depth() <= 1 THEN
      NEW.driver_status := OLD.driver_status;
    END IF;
  END IF;

  -- ج. مزامنة الدور إلى auth.users.raw_app_meta_data للـ JWT Claims
  IF NEW.is_driver IS DISTINCT FROM OLD.is_driver OR NEW.driver_status IS DISTINCT FROM OLD.driver_status THEN
    BEGIN
      UPDATE auth.users
      SET raw_app_meta_data = raw_app_meta_data || 
          jsonb_build_object(
            'role', CASE WHEN NEW.is_driver THEN 'driver' ELSE 'passenger' END,
            'driver_status', NEW.driver_status
          )
      WHERE id = NEW.id;
    EXCEPTION WHEN OTHERS THEN
      -- تجاهل الخطأ إن لم تكن هناك صلاحية للوصول لـ auth.users
    END;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

DROP TRIGGER IF EXISTS tr_guard_profile_sensitive_fields ON public.profiles;
CREATE TRIGGER tr_guard_profile_sensitive_fields
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.guard_profile_sensitive_fields();

-- 3. دالة آمنة لطلب تفعيل حساب سائق (Driver Application Request)
CREATE OR REPLACE FUNCTION public.request_driver_activation()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  UPDATE public.profiles
  SET is_driver = true,
      driver_status = 'approved', -- أو 'pending' للمراجعة اليدوية
      updated_at = NOW()
  WHERE id = v_user_id;

  RETURN jsonb_build_object('success', true, 'driver_status', 'approved');
END;
$$;
