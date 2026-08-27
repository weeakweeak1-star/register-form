-- ==============================================================================
-- Migration: Unified accept_taxi_request with SKIP LOCKED + Balance Check
-- ==============================================================================
-- يُوحّد نسختي الدالة في نسخة واحدة تجمع:
--   ✅ قفل صف الطلب بـ FOR UPDATE SKIP LOCKED (بدون انتظار)
--   ✅ قفل صف driver_online_status لمنع نفس السائق من قبول طلبين
--   ✅ التحقق من الرصيد المالي (الحد الأدنى -5000)
--   ✅ التحقق من عدم وجود رحلة نشطة أخرى
--   ✅ إرجاع رسالة خطأ واضحة بدلاً من الانتظار
-- ==============================================================================

-- إزالة النسخ القديمة (كلا التوقيعين)
DROP FUNCTION IF EXISTS public.accept_taxi_request(UUID);
DROP FUNCTION IF EXISTS public.accept_taxi_request(UUID, UUID);

CREATE OR REPLACE FUNCTION public.accept_taxi_request(p_request_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id UUID;
  v_is_driver BOOLEAN;
  v_driver_status TEXT;
  v_request RECORD;
  v_balance NUMERIC;
  v_active_taxi_count INT;
  v_active_trip_count INT;
  v_lock_acquired BOOLEAN;
BEGIN
  -- ──────────────────────────────────────────────────────────
  -- 1. التحقق من هوية السائق
  -- ──────────────────────────────────────────────────────────
  v_driver_id := auth.uid();
  
  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- ──────────────────────────────────────────────────────────
  -- 2. التحقق من أن المستخدم سائق معتمد
  -- ──────────────────────────────────────────────────────────
  SELECT is_driver, driver_status INTO v_is_driver, v_driver_status
  FROM public.profiles
  WHERE id = v_driver_id;

  IF v_is_driver IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_A_DRIVER');
  END IF;

  IF v_driver_status IS DISTINCT FROM 'approved' THEN
    RETURN jsonb_build_object('success', false, 'error', 'DRIVER_NOT_APPROVED');
  END IF;

  -- ──────────────────────────────────────────────────────────
  -- 3. التحقق من الرصيد المالي (الحد الأدنى -5000)
  -- ──────────────────────────────────────────────────────────
  SELECT balance INTO v_balance FROM public.driver_wallets WHERE driver_id = v_driver_id;
  IF v_balance IS NOT NULL AND v_balance <= -5000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'INSUFFICIENT_BALANCE');
  END IF;

  -- ──────────────────────────────────────────────────────────
  -- 4. قفل صف حالة السائق لمنعه من قبول طلبين في نفس اللحظة
  --    SKIP LOCKED: إذا كان الصف مقفولاً مسبقاً (طلب آخر قيد المعالجة)
  --    يرجع فوراً بدلاً من الانتظار
  -- ──────────────────────────────────────────────────────────
  SELECT true INTO v_lock_acquired
  FROM public.driver_online_status
  WHERE driver_id = v_driver_id
  FOR UPDATE SKIP LOCKED;

  IF v_lock_acquired IS NULL THEN
    -- الصف مقفول = السائق يعالج طلباً آخر حالياً
    RETURN jsonb_build_object('success', false, 'error', 'DRIVER_BUSY');
  END IF;

  -- ──────────────────────────────────────────────────────────
  -- 5. التحقق من عدم وجود طلب تكسي نشط آخر
  -- ──────────────────────────────────────────────────────────
  SELECT COUNT(*) INTO v_active_taxi_count
  FROM public.taxi_requests
  WHERE driver_id = v_driver_id
    AND status IN ('accepted', 'arrived', 'ongoing');
    
  IF v_active_taxi_count > 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'DRIVER_HAS_ACTIVE_TAXI');
  END IF;

  -- ──────────────────────────────────────────────────────────
  -- 6. التحقق من عدم وجود رحلة مشتركة نشطة
  -- ──────────────────────────────────────────────────────────
  SELECT COUNT(*) INTO v_active_trip_count
  FROM public.trips
  WHERE driver_id = v_driver_id
    AND status IN ('started', 'ongoing');

  IF v_active_trip_count > 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'DRIVER_HAS_ACTIVE_TRIP');
  END IF;

  -- ──────────────────────────────────────────────────────────
  -- 7. قفل صف الطلب بـ SKIP LOCKED
  --    إذا سبقه سائق آخر، يرجع فوراً بدون انتظار
  -- ──────────────────────────────────────────────────────────
  SELECT id, passenger_id, status, driver_id
  INTO v_request
  FROM public.taxi_requests
  WHERE id = p_request_id
  FOR UPDATE SKIP LOCKED;

  -- الطلب مقفول من سائق آخر أو غير موجود
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'ALREADY_TAKEN');
  END IF;

  -- التحقق من أن السائق ليس هو الراكب
  IF v_request.passenger_id = v_driver_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'CANNOT_ACCEPT_OWN_REQUEST');
  END IF;

  -- التحقق من أن الطلب لا يزال في حالة البحث
  IF v_request.status <> 'searching' OR v_request.driver_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'ALREADY_TAKEN');
  END IF;

  -- ──────────────────────────────────────────────────────────
  -- 8. التعيين الذري: تحديث الطلب
  -- ──────────────────────────────────────────────────────────
  UPDATE public.taxi_requests
  SET driver_id = v_driver_id,
      status = 'accepted',
      updated_at = NOW()
  WHERE id = p_request_id;

  RETURN jsonb_build_object('success', true, 'request_id', p_request_id);
END;
$$;

-- ──────────────────────────────────────────────────────────
-- تحديث استدعاء الكود في الـ repository ليستخدم التوقيع الجديد
-- الدالة الآن تأخذ p_request_id فقط وتستنتج السائق من auth.uid()
-- ──────────────────────────────────────────────────────────
COMMENT ON FUNCTION public.accept_taxi_request(UUID) IS 
  'Atomically accepts a taxi request. Uses FOR UPDATE SKIP LOCKED to avoid blocking. 
   Validates: driver role, balance, no active trips, and request availability.
   Call via: SELECT accept_taxi_request(''<request-uuid>'')';
