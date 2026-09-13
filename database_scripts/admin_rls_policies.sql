-- ==============================================================================
-- إعطاء صلاحيات للمدير لرؤية جميع الرحلات المكتملة (Trips & Taxi)
-- ==============================================================================

-- 1. إضافة عمود is_admin لجدول الحسابات (profiles)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;

-- 2. سياسة قراءة جميع الرحلات للمدير (جدول trips)
DROP POLICY IF EXISTS "Admins can view all trips" ON public.trips;
CREATE POLICY "Admins can view all trips" ON public.trips
    FOR ALL TO authenticated
    USING ( (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true )
    WITH CHECK ( (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true );

-- 3. سياسة قراءة جميع طلبات التكسي للمدير (جدول taxi_requests)
DROP POLICY IF EXISTS "Admins can view all taxi requests" ON public.taxi_requests;
CREATE POLICY "Admins can view all taxi requests" ON public.taxi_requests
    FOR ALL TO authenticated
    USING ( (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true )
    WITH CHECK ( (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true );

-- 4. إعطاء صلاحية المدير لرقم هاتف المدير الحالي (استبدل رقم الهاتف برقمك)
-- قم بتغيير رقم الهاتف في السطر التالي إلى رقم هاتف حساب المدير الخاص بك
-- UPDATE public.profiles SET is_admin = true WHERE phone = '+9647701234567';
