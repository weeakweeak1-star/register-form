-- ==============================================================================
-- Migration: Secure taxi_requests RLS UPDATE Policy & Atomic Acceptance
-- ==============================================================================

-- 1. إزالة السياسة السابقة التي كانت تتيح التعديل لأي مستخدم طالما status = 'searching'
DROP POLICY IF EXISTS "users can update their own requests or drivers can accept them" ON public.taxi_requests;
DROP POLICY IF EXISTS "passengers can update own requests" ON public.taxi_requests;
DROP POLICY IF EXISTS "assigned drivers can update requests" ON public.taxi_requests;
DROP POLICY IF EXISTS "drivers can accept searching requests" ON public.taxi_requests;

-- 2. السياسة الأولى: الراكب صاحب الطلب فقط يمكنه تعديل أو إلغاء طلبه
CREATE POLICY "passengers can update own requests" ON public.taxi_requests
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = passenger_id)
    WITH CHECK (auth.uid() = passenger_id);

-- 3. السياسة الثانية: السائق المعين للرحلة فقط يمكنه تحديث حالة المشوار (وصل، انطلق، اكتمل، ألغي)
CREATE POLICY "assigned drivers can update requests" ON public.taxi_requests
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = driver_id)
    WITH CHECK (auth.uid() = driver_id);

-- 4. السياسة الثالثة: قبول الطلبات الجديدة محصور بالسائقين المعتمدين فقط
-- وتلزم السائق بتعيين نفسه driver_id وتغيير الحالة إلى accepted دون السماح له بتعديل بيانات الرحلة أو السعر
CREATE POLICY "drivers can accept searching requests" ON public.taxi_requests
    FOR UPDATE
    TO authenticated
    USING (
        status = 'searching' 
        AND driver_id IS NULL
        AND auth.uid() <> passenger_id
        AND EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND is_driver = true
        )
    )
    WITH CHECK (
        driver_id = auth.uid()
        AND status = 'accepted'
    );

-- 5. دالة RPC ذرية ومحمية لقبول طلبات التكسي مع قفل الصف لمنع تضارب السائقين (Race Conditions)
CREATE OR REPLACE FUNCTION public.accept_taxi_request(p_request_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id UUID;
  v_is_driver BOOLEAN;
  v_request RECORD;
BEGIN
  v_driver_id := auth.uid();
  
  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- التحقق من أن المستخدم سائق معتمد
  SELECT is_driver INTO v_is_driver
  FROM public.profiles
  WHERE id = v_driver_id;

  IF v_is_driver IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_A_DRIVER');
  END IF;

  -- قفل صف الطلب برمجياً
  SELECT id, passenger_id, status, driver_id
  INTO v_request
  FROM public.taxi_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'REQUEST_NOT_FOUND');
  END IF;

  IF v_request.passenger_id = v_driver_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'CANNOT_ACCEPT_OWN_REQUEST');
  END IF;

  IF v_request.status <> 'searching' OR v_request.driver_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'ALREADY_TAKEN');
  END IF;

  -- تعيين السائق وقبول الطلب
  UPDATE public.taxi_requests
  SET driver_id = v_driver_id,
      status = 'accepted',
      updated_at = NOW()
  WHERE id = p_request_id;

  RETURN jsonb_build_object('success', true, 'request_id', p_request_id);
END;
$$;
