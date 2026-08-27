-- ==============================================================================
-- Fix RLS Policy for Private Trips and Bookings
-- هذا السكربت يحل مشكلة الخطأ:
-- PostgrestException(message: Cannot coerce the result to a single JSON object, code: PGRST116)
-- عند حجز الرحلات الخاصة
-- ==============================================================================

-- 1. التأكد من تفعيل RLS على جدولي trips و bookings
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- 2. تحديث سياسة قراءة وتصفح الرحلات (trips)
-- السماح للركاب بالبحث واستعراض وحجز الرحلات الخاصة والتشاركية المتاحة
DROP POLICY IF EXISTS "Public trips are viewable for search and booking" ON public.trips;
CREATE POLICY "Public trips are viewable for search and booking" ON public.trips
    FOR SELECT TO authenticated
    USING (
        (status IN ('scheduled', 'started') AND available_seats > 0)
    );

-- 3. التأكد من سياسات قراءة وإضافة الحجوزات (bookings)
DROP POLICY IF EXISTS "Passengers can insert their own bookings" ON public.bookings;
CREATE POLICY "Passengers can insert their own bookings" ON public.bookings
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = passenger_id);

DROP POLICY IF EXISTS "Passengers can view their own bookings" ON public.bookings;
CREATE POLICY "Passengers can view their own bookings" ON public.bookings
    FOR SELECT TO authenticated
    USING (auth.uid() = passenger_id);

DROP POLICY IF EXISTS "Users can manage their own bookings" ON public.bookings;
CREATE POLICY "Users can manage their own bookings" ON public.bookings
    FOR ALL TO authenticated
    USING (auth.uid() = passenger_id)
    WITH CHECK (auth.uid() = passenger_id);
