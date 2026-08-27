-- Run this script to add the missing seat decrement function
-- It is safe to run even if the function already exists (it will update it).

CREATE OR REPLACE FUNCTION public.decrement_seats(trip_id uuid, seats int)
RETURNS void AS $$
BEGIN
  -- Update the trip's available seats only if there are enough seats
  UPDATE public.trips
  SET available_seats = available_seats - seats
  WHERE id = trip_id AND available_seats >= seats;
  
  -- If no row was updated, it means either the trip doesn't exist or not enough seats
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Not enough seats available';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
