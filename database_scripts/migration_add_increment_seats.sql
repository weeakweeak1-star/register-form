-- Function to increment available seats (e.g. when a booking is cancelled/rejected)
CREATE OR REPLACE FUNCTION public.increment_seats(trip_id uuid, seats int)
RETURNS void AS $$
BEGIN
  UPDATE public.trips
  SET available_seats = available_seats + seats
  WHERE id = trip_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
