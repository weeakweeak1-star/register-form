-- Create function to get all incoming pending bookings for a driver across all their trips
CREATE OR REPLACE FUNCTION public.get_incoming_bookings_for_driver(p_driver_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_agg(
    json_build_object(
      'id', b.id,
      'trip_id', b.trip_id,
      'passenger_id', b.passenger_id,
      'seats_booked', b.seats_booked,
      'total_price', b.total_price,
      'status', b.status,
      'created_at', b.created_at,
      'pickup_point', CASE WHEN jsonb_typeof(b.pickup_point) = 'object' THEN b.pickup_point ELSE NULL END,
      'trip', (
        SELECT json_build_object(
          'id', t.id,
          'driver_id', t.driver_id,
          'origin', t.origin,
          'destination', t.destination,
          'departure_time', t.departure_time,
          'total_seats', t.total_seats,
          'available_seats', COALESCE(t.available_seats, t.total_seats),
          'status', t.status,
          'is_private', t.is_private,
          'price_per_seat', t.price_per_seat
        )
        FROM public.trips t
        WHERE t.id = b.trip_id
      ),
      'profiles', (
        SELECT json_build_object(
          'id', p.id,
          'email', COALESCE(p.email, ''),
          'full_name', COALESCE(p.full_name, 'Unknown User'),
          'phone_number', p.phone,
          'avatar_url', p.avatar_url,
          'rating', p.rating,
          'is_driver', COALESCE(p.is_driver, false)
        )
        FROM public.profiles p
        WHERE p.id = b.passenger_id
      )
    ) ORDER BY b.created_at DESC
  ) INTO result
  FROM public.bookings b
  JOIN public.trips t ON b.trip_id = t.id
  WHERE t.driver_id = p_driver_id
  AND b.status = 'pending';

  RETURN COALESCE(result, '[]'::json);
END;
$$;
