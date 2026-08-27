-- Drop potential ambiguous versions of the function to avoid conflicts
DROP FUNCTION IF EXISTS public.create_booking(uuid, uuid, integer, double precision, uuid);
DROP FUNCTION IF EXISTS public.create_booking(uuid, uuid, integer, numeric, uuid);

-- Create function to handle booking creation (Pending status)
-- NOTE: Seats are NOT decremented on create_booking when status is 'pending'.
-- Seats are decremented ONLY when the captain accepts/confirms the booking.
CREATE OR REPLACE FUNCTION public.create_booking(
  p_trip_id UUID,
  p_passenger_id UUID,
  p_seats_booked INT,
  p_total_price DOUBLE PRECISION DEFAULT NULL,
  p_pickup_point_id UUID DEFAULT NULL 
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trip RECORD;
  v_booking_id UUID;
  v_calculated_price NUMERIC;
  v_existing_booking_count INT;
BEGIN
  -- 1. قفل صف الرحلة للتحقق من المقاعد والحالة ومنع التعارض اللحظي
  SELECT id, driver_id, available_seats, price_per_seat, is_private, total_seats, status
  INTO v_trip
  FROM public.trips
  WHERE id = p_trip_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'TRIP_NOT_FOUND: Trip does not exist';
  END IF;

  -- 2. منع الحجز على الرحلات المنتهية أو الملغاة
  IF v_trip.status IN ('completed', 'cancelled') THEN
    RAISE EXCEPTION 'TRIP_NOT_BOOKABLE: Cannot book a trip that is completed or cancelled';
  END IF;

  -- 3. منع الحجز على رحلة خاصة انطلقت بالفعل
  IF v_trip.is_private AND v_trip.status IN ('started', 'ongoing') THEN
    RAISE EXCEPTION 'PRIVATE_TRIP_ALREADY_STARTED: Cannot book a private trip that has already departed';
  END IF;

  -- 4. منع السائق من حجز مقعد في رحلته
  IF v_trip.driver_id = p_passenger_id THEN
    RAISE EXCEPTION 'CANNOT_BOOK_OWN_TRIP: Drivers cannot book seats on their own trips';
  END IF;

  -- 5. التحقق من المقاعد
  IF p_seats_booked IS NULL OR p_seats_booked <= 0 THEN
    RAISE EXCEPTION 'INVALID_SEATS_COUNT: Seats booked must be at least 1';
  END IF;

  IF v_trip.available_seats < p_seats_booked THEN
    RAISE EXCEPTION 'NOT_ENOUGH_SEATS: Only % seats available', v_trip.available_seats;
  END IF;

  -- 6. منع الحجز النشط المكرر لنفس الراكب في نفس الرحلة
  SELECT COUNT(*) INTO v_existing_booking_count
  FROM public.bookings
  WHERE trip_id = p_trip_id 
    AND passenger_id = p_passenger_id
    AND status IN ('pending', 'accepted', 'confirmed', 'arrived', 'started', 'ongoing');

  IF v_existing_booking_count > 0 THEN
    RAISE EXCEPTION 'DUPLICATE_ACTIVE_BOOKING: You already have an active booking on this trip';
  END IF;

  -- 7. حساب السعر من قاعدة البيانات
  IF v_trip.is_private THEN
    v_calculated_price := v_trip.price_per_seat;
  ELSE
    v_calculated_price := p_seats_booked * v_trip.price_per_seat;
  END IF;

  -- 8. إدراج الحجز بحالة معلقة
  INSERT INTO public.bookings (trip_id, passenger_id, seats_booked, total_price, status)
  VALUES (p_trip_id, p_passenger_id, p_seats_booked, v_calculated_price, 'pending')
  RETURNING id INTO v_booking_id;

  RETURN v_booking_id;
END;
$$;

-- Trigger to calculate and validate booking total_price for direct table inserts
CREATE OR REPLACE FUNCTION public.calculate_and_validate_booking_total_price()
RETURNS TRIGGER AS $$
DECLARE
  v_trip RECORD;
  v_expected_price NUMERIC;
BEGIN
  SELECT id, driver_id, price_per_seat, is_private, total_seats, available_seats, status
  INTO v_trip
  FROM public.trips
  WHERE id = NEW.trip_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'TRIP_NOT_FOUND: Trip % does not exist', NEW.trip_id;
  END IF;

  IF v_trip.status IN ('completed', 'cancelled') THEN
    RAISE EXCEPTION 'TRIP_NOT_BOOKABLE: Cannot book a trip with status %', v_trip.status;
  END IF;

  IF v_trip.is_private AND v_trip.status IN ('started', 'ongoing') THEN
    RAISE EXCEPTION 'PRIVATE_TRIP_ALREADY_STARTED: Cannot book an ongoing private trip';
  END IF;

  IF v_trip.driver_id = NEW.passenger_id THEN
    RAISE EXCEPTION 'CANNOT_BOOK_OWN_TRIP: Drivers cannot book seats on their own trips';
  END IF;

  IF NEW.seats_booked IS NULL OR NEW.seats_booked <= 0 THEN
    RAISE EXCEPTION 'INVALID_SEATS: seats_booked must be greater than 0';
  END IF;

  IF v_trip.is_private THEN
    v_expected_price := v_trip.price_per_seat;
  ELSE
    v_expected_price := NEW.seats_booked * v_trip.price_per_seat;
  END IF;

  NEW.total_price := v_expected_price;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_validate_and_calculate_booking_price ON public.bookings;
CREATE TRIGGER tr_validate_and_calculate_booking_price
BEFORE INSERT OR UPDATE OF seats_booked, trip_id ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.calculate_and_validate_booking_total_price();


-- Create function to get bookings for a trip with passenger details (Bypass RLS)
CREATE OR REPLACE FUNCTION public.get_trip_bookings_for_driver(p_trip_id UUID)
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
  WHERE b.trip_id = p_trip_id;

  RETURN COALESCE(result, '[]'::json);
END;
$$;


-- Optional SQL helper to sync/recalculate available_seats on trips table:
-- UPDATE public.trips t
-- SET available_seats = t.total_seats - COALESCE(
--   (SELECT SUM(b.seats_booked)
--    FROM public.bookings b
--    WHERE b.trip_id = t.id
--      AND b.status IN ('accepted', 'confirmed', 'arrived', 'started', 'ongoing')
--   ), 0
-- );
