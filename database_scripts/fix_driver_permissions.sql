-- Fix permissions for Drivers to create trips (and manage their own)
-- Run this in Supabase Dashboard -> SQL Editor

-- 1. Drop potentially conflicting policies (FIXED: Removing trailing period)
DROP POLICY IF EXISTS "Drivers can manage their own trips" ON public.trips;
DROP POLICY IF EXISTS "Drivers can create trips" ON public.trips;
DROP POLICY IF EXISTS "Drivers can manage their own trips." ON public.trips; -- old one just in case

-- 2. Create the correct policy for Drivers
CREATE POLICY "Drivers can manage their own trips"
ON public.trips
FOR ALL
TO authenticated
USING (
  auth.uid() = driver_id
)
WITH CHECK (
  auth.uid() = driver_id
);
