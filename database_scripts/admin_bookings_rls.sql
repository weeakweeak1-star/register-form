-- سياسة قراءة جميع الحجوزات للمدير (جدول bookings)
DROP POLICY IF EXISTS "Admins can view all bookings" ON public.bookings;
CREATE POLICY "Admins can view all bookings" ON public.bookings
    FOR ALL TO authenticated
    USING ( (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true )
    WITH CHECK ( (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true );
