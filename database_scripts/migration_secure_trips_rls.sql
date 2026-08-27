-- ==============================================================================
-- Migration: Secure trips Table RLS Policies & Private Trips Protection
-- ==============================================================================

-- 1. إزالة السياسات السابقة المتساهلة
DROP POLICY IF EXISTS "Trips are viewable by everyone." ON public.trips;
DROP POLICY IF EXISTS "Drivers can manage their own trips." ON public.trips;
DROP POLICY IF EXISTS "Public trips are viewable for search and booking" ON public.trips;
DROP POLICY IF EXISTS "Drivers can view their own trips" ON public.trips;
DROP POLICY IF EXISTS "Passengers can view trips they booked" ON public.trips;
DROP POLICY IF EXISTS "Drivers can insert their own trips" ON public.trips;
DROP POLICY IF EXISTS "Drivers can update their own trips" ON public.trips;
DROP POLICY IF EXISTS "Drivers can delete their own trips" ON public.trips;

-- 2. دالة مساعدة مع SECURITY DEFINER لمنع التكرار اللانهائي في RLS
CREATE OR REPLACE FUNCTION public.check_user_has_booking(p_trip_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.bookings
    WHERE trip_id = p_trip_id AND passenger_id = p_user_id
  );
$$;

CREATE OR REPLACE FUNCTION public.check_is_driver(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT is_driver FROM public.profiles WHERE id = p_user_id),
    false
  );
$$;

-- 3. سياسات القراءة (SELECT):
-- أ. السائق يرى جميع رحلاته (المجدولة، النشطة، المكتملة، والملغاة)
CREATE POLICY "Drivers can view their own trips" ON public.trips
    FOR SELECT TO authenticated
    USING (auth.uid() = driver_id);

-- ب. الركاب الذين حجزوا في الرحلة يرون تفاصيلها وإحداثياتها المباشرة
CREATE POLICY "Passengers can view trips they booked" ON public.trips
    FOR SELECT TO authenticated
    USING (public.check_user_has_booking(id, auth.uid()));

-- ج. تصفح الرحلات المتاحة للجمهور للبحث والحجز:
-- - الرحلات التشاركية: المتاحة وبها مقاعد شاغرة (scheduled أو started)
-- - الرحلات الخاصة: المجدولة فقط والتي لم تُحجز بعد بالكامل (available_seats = total_seats)
-- وبمجرد حجز الرحلة الخاصة تختفي تماماً عن بقية المستخدمين لحماية خصوصية الراكب والسائق ومسار الرحلة
CREATE POLICY "Public trips are viewable for search and booking" ON public.trips
    FOR SELECT TO authenticated
    USING (
        (is_private = false AND status IN ('scheduled', 'started') AND available_seats > 0)
        OR
        (is_private = true AND status = 'scheduled' AND available_seats = total_seats)
    );

-- 4. سياسة الإدراج (INSERT):
-- محصورة بالسائقين المعتمدين (is_driver = true) وتلزمهم بتعيين أنفسهم driver_id
CREATE POLICY "Drivers can insert their own trips" ON public.trips
    FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = driver_id 
        AND public.check_is_driver(auth.uid()) = true
    );

-- 5. سياسة التعديل (UPDATE):
-- السائق صاحب الرحلة فقط يمكنه تعديلها وتحديث موقعها وحالتها
CREATE POLICY "Drivers can update their own trips" ON public.trips
    FOR UPDATE TO authenticated
    USING (auth.uid() = driver_id)
    WITH CHECK (auth.uid() = driver_id);

-- 6. سياسة الحذف (DELETE):
-- السائق صاحب الرحلة فقط
CREATE POLICY "Drivers can delete their own trips" ON public.trips
    FOR DELETE TO authenticated
    USING (auth.uid() = driver_id);
