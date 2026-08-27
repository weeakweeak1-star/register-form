-- Fix permissions for Passengers to create bookings
-- Run this in Supabase Dashboard -> SQL Editor

-- 1. Drop potentially conflicting policies
DROP POLICY IF EXISTS "Users can manage their own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Passengers can create bookings" ON public.bookings;
DROP POLICY IF EXISTS "Users can manage their own bookings." ON public.bookings;

-- 2. Create the correct policy
CREATE POLICY "Users can manage their own bookings"
ON public.bookings
FOR ALL
TO authenticated
USING (
  auth.uid() = passenger_id
)
WITH CHECK (
  auth.uid() = passenger_id
);

-- Note: This policy allows INSERT/UPDATE/DELETE/SELECT if the passenger_id matches the auth user id.
-- This combined with "Drivers can view bookings for their trips" (from fix_bookings_permissions.sql) covers all cases.
