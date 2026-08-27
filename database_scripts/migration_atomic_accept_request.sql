-- ==============================================================================
-- Migration: Atomic Accept Taxi Request Function (RPC)
-- ==============================================================================

-- تُنشئ دالة آمنة وذرية (Atomic) لقبول الطلبات.
-- تحل مشكلة الـ Race Condition وتمنع سائقين من قبول نفس الطلب، 
-- وتمنع نفس السائق من قبول طلبين في نفس الوقت.

CREATE OR REPLACE FUNCTION accept_taxi_request(
  p_request_id UUID,
  p_driver_id UUID
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER -- يعمل بصلاحيات الأدمن لضمان اكتمال التعديلات داخل الدالة
AS $$
DECLARE
  v_active_requests INT;
  v_active_trips INT;
  v_updated_rows INT;
BEGIN
  -- 1. قفل صف السائق (Lock) لمنع السائق نفسه من إرسال طلبين قبول في نفس اللحظة
  PERFORM 1 FROM public.driver_online_status WHERE driver_id = p_driver_id FOR UPDATE;

  -- 2. التحقق مما إذا كان السائق مشغولاً برحلة تكسي أخرى حالياً
  SELECT COUNT(*) INTO v_active_requests
  FROM public.taxi_requests
  WHERE driver_id = p_driver_id
    AND status IN ('accepted', 'arrived', 'ongoing');
    
  IF v_active_requests > 0 THEN
    RETURN FALSE;
  END IF;

  -- 3. التحقق مما إذا كان السائق مشغولاً برحلة مبرمجة (Carpool) حالياً
  SELECT COUNT(*) INTO v_active_trips
  FROM public.trips
  WHERE driver_id = p_driver_id
    AND status IN ('started', 'ongoing');

  IF v_active_trips > 0 THEN
    RETURN FALSE;
  END IF;

  -- 4. التعديل الذري: تحديث الطلب فقط إذا كان لا يزال يبحث عن سائق
  UPDATE public.taxi_requests
  SET status = 'accepted',
      driver_id = p_driver_id
  WHERE id = p_request_id
    AND status = 'searching';

  GET DIAGNOSTICS v_updated_rows = ROW_COUNT;

  -- إذا تم التحديث بنجاح، نُرجع True، وإلا (لو سبقه سائق آخر) نُرجع False
  IF v_updated_rows > 0 THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$;
