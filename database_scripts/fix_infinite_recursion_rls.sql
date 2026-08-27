-- ==============================================================================
-- Migration: Fix Infinite Recursion in RLS Policies for trips and bookings
-- Error Code: 42P17 (infinite recursion detected in policy for relation "trips")
-- ==============================================================================

-- 1. دوال مساعدة مع SECURITY DEFINER لكسر التداخل والاعتماد الدائري في RLS
-- هذه الدوال تعمل بصلاحيات النظام متجاوزة تكرار فحص السياسات (RLS Recursion)

-- أ. التحقق مما إذا كان المستخدم راكباً حجز في الرحلة
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

-- ب. التحقق مما إذا كان المستخدم هو سائق الرحلة
CREATE OR REPLACE FUNCTION public.check_is_trip_driver(p_trip_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.trips
    WHERE id = p_trip_id AND driver_id = p_user_id
  );
$$;

-- ج. التحقق مما إذا كان المستخدم سائقاً معتمداً
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

-- ==============================================================================
-- 2. إعادة ضبط سياسات جدول الرحلات public.trips
-- ==============================================================================

ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Trips are viewable by everyone." ON public.trips;
DROP POLICY IF EXISTS "Drivers can manage their own trips." ON public.trips;
DROP POLICY IF EXISTS "Public trips are viewable for search and booking" ON public.trips;
DROP POLICY IF EXISTS "Drivers can view their own trips" ON public.trips;
DROP POLICY IF EXISTS "Passengers can view trips they booked" ON public.trips;
DROP POLICY IF EXISTS "Drivers can insert their own trips" ON public.trips;
DROP POLICY IF EXISTS "Drivers can update their own trips" ON public.trips;
DROP POLICY IF EXISTS "Drivers can delete their own trips" ON public.trips;

-- أ. السائق يرى رحلاته الخاصة
CREATE POLICY "Drivers can view their own trips" ON public.trips
    FOR SELECT TO authenticated
    USING (auth.uid() = driver_id);

-- ب. الركاب يرون الرحلات التي قاموا بحجزها عبر الدالة الآمنة (دون حدوث تكرار لا نهائي)
CREATE POLICY "Passengers can view trips they booked" ON public.trips
    FOR SELECT TO authenticated
    USING (public.check_user_has_booking(id, auth.uid()));

-- ج. تصفح الرحلات المتاحة للجمهور
CREATE POLICY "Public trips are viewable for search and booking" ON public.trips
    FOR SELECT TO authenticated
    USING (
        (is_private = false AND status IN ('scheduled', 'started') AND available_seats > 0)
        OR
        (is_private = true AND status = 'scheduled' AND available_seats = total_seats)
    );

-- د. إدراج رحلة جديدة محصور بالسائقين المعتمدين
CREATE POLICY "Drivers can insert their own trips" ON public.trips
    FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = driver_id 
        AND public.check_is_driver(auth.uid()) = true
    );

-- هـ. تعديل الرحلة محصور بالسائق صاحب الرحلة
CREATE POLICY "Drivers can update their own trips" ON public.trips
    FOR UPDATE TO authenticated
    USING (auth.uid() = driver_id)
    WITH CHECK (auth.uid() = driver_id);

-- و. حذف الرحلة محصور بالسائق صاحب الرحلة
CREATE POLICY "Drivers can delete their own trips" ON public.trips
    FOR DELETE TO authenticated
    USING (auth.uid() = driver_id);


-- ==============================================================================
-- 3. إعادة ضبط سياسات جدول الحجوزات public.bookings
-- ==============================================================================

ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Users can manage their own bookings." ON public.bookings;
DROP POLICY IF EXISTS "Passengers can create bookings" ON public.bookings;
DROP POLICY IF EXISTS "Drivers can view bookings for their trips" ON public.bookings;
DROP POLICY IF EXISTS "Drivers can update bookings for their trips" ON public.bookings;
DROP POLICY IF EXISTS "Passengers can view their own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Passengers can insert their own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Passengers can update their own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Passengers can delete their own bookings" ON public.bookings;

-- أ. الراكب يستعرض حجوزاته الخاصة
CREATE POLICY "Passengers can view their own bookings" ON public.bookings
    FOR SELECT TO authenticated
    USING (auth.uid() = passenger_id);

-- ب. السائق يستعرض الحجوزات التابعة لرحلاته عبر الدالة الآمنة (دون حدوث تكرار لا نهائي)
CREATE POLICY "Drivers can view bookings for their trips" ON public.bookings
    FOR SELECT TO authenticated
    USING (public.check_is_trip_driver(trip_id, auth.uid()));

-- ج. الراكب ينشئ حجزاً لنفسه
CREATE POLICY "Passengers can insert their own bookings" ON public.bookings
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = passenger_id);

-- د. الراكب يعدل حجزه
CREATE POLICY "Passengers can update their own bookings" ON public.bookings
    FOR UPDATE TO authenticated
    USING (auth.uid() = passenger_id)
    WITH CHECK (auth.uid() = passenger_id);

-- هـ. السائق يقبل أو يرفض أو يغير حالة الحجوزات في رحلته
CREATE POLICY "Drivers can update bookings for their trips" ON public.bookings
    FOR UPDATE TO authenticated
    USING (public.check_is_trip_driver(trip_id, auth.uid()))
    WITH CHECK (public.check_is_trip_driver(trip_id, auth.uid()));

-- و. الراكب يحذف/يلغي حجزه
CREATE POLICY "Passengers can delete their own bookings" ON public.bookings
    FOR DELETE TO authenticated
    USING (auth.uid() = passenger_id);
