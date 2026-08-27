-- Fixed: Ensure the bookings table receives real-time updates
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'bookings'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE bookings;
  END IF;
END $$;

-- Helper function to check if user is the driver of the trip (bypasses RLS recursion)
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

-- Fixed: Allow drivers to view bookings for their own trips
DROP POLICY IF EXISTS "Drivers can view bookings for their trips" ON public.bookings;
CREATE POLICY "Drivers can view bookings for their trips" ON public.bookings
FOR SELECT USING (
  public.check_is_trip_driver(trip_id, auth.uid())
);

-- Fixed: Allow drivers to update booking status (accept/reject)
DROP POLICY IF EXISTS "Drivers can update bookings for their trips" ON public.bookings;
CREATE POLICY "Drivers can update bookings for their trips" ON public.bookings
FOR UPDATE USING (
  public.check_is_trip_driver(trip_id, auth.uid())
)
WITH CHECK (
  public.check_is_trip_driver(trip_id, auth.uid())
);
