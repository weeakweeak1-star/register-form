-- Safe & Flexible SQL Migration for Real-Time Publications

DO $$ 
BEGIN
  -- Create publication if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;

  -- Add trips if table exists and not already a member
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trips')
     AND NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'trips') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.trips;
  END IF;

  -- Add bookings if table exists and not already a member
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'bookings')
     AND NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'bookings') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
  END IF;

  -- Add taxi_requests if table exists and not already a member
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'taxi_requests')
     AND NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'taxi_requests') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.taxi_requests;
  END IF;

  -- Add driver_locations if table exists and not already a member
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'driver_locations')
     AND NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'driver_locations') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_locations;
  END IF;
END $$;
