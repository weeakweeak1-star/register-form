-- ==============================================================================
-- Migration: Secure Booking Validation (Trip Status, Driver Self-Booking, Seat Limits)
-- ==============================================================================

-- 1. إضافة قيود فحص حالات جدول الرحلات trips
ALTER TABLE public.trips
DROP CONSTRAINT IF EXISTS trips_status_check;

ALTER TABLE public.trips
ADD CONSTRAINT trips_status_check 
CHECK (status IN ('scheduled', 'started', 'ongoing', 'completed', 'cancelled'));

-- 2. إضافة قيود فحص حالات جدول الحجوزات bookings
ALTER TABLE public.bookings
DROP CONSTRAINT IF EXISTS bookings_status_check;

ALTER TABLE public.bookings
ADD CONSTRAINT bookings_status_check 
CHECK (status IN ('pending', 'accepted', 'confirmed', 'rejected', 'cancelled', 'arrived', 'started', 'ongoing', 'completed'));

-- 3. تحديث دالة RPC create_booking مع كافة شروط الحماية الصارمة
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
  -- 1. قفل صف الرحلة في الـ DB لمنع تضارب الحجوزات المتزامنة (Race Condition Protection)
  SELECT id, driver_id, available_seats, price_per_seat, is_private, total_seats, status
  INTO v_trip
  FROM public.trips
  WHERE id = p_trip_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'TRIP_NOT_FOUND: Trip does not exist';
  END IF;

  -- 2. التحقق من حالة الرحلة: منع الحجز على الرحلات المنتهية أو الملغاة
  IF v_trip.status IN ('completed', 'cancelled') THEN
    RAISE EXCEPTION 'TRIP_NOT_BOOKABLE: Cannot book a trip that is completed or cancelled';
  END IF;

  -- 3. في الرحلات الخاصة: لا يمكن الحجز إذا كانت الرحلة قد انطلقت بالفعل
  IF v_trip.is_private AND v_trip.status IN ('started', 'ongoing') THEN
    RAISE EXCEPTION 'PRIVATE_TRIP_ALREADY_STARTED: Cannot book a private trip that has already departed';
  END IF;

  -- 4. منع السائق من حجز مقعد في رحلته الخاصة
  IF v_trip.driver_id = p_passenger_id THEN
    RAISE EXCEPTION 'CANNOT_BOOK_OWN_TRIP: Drivers cannot book seats on their own trips';
  END IF;

  -- 5. التحقق من صحة عدد المقاعد المطلوبة
  IF p_seats_booked IS NULL OR p_seats_booked <= 0 THEN
    RAISE EXCEPTION 'INVALID_SEATS_COUNT: Seats booked must be at least 1';
  END IF;

  IF v_trip.available_seats < p_seats_booked THEN
    RAISE EXCEPTION 'NOT_ENOUGH_SEATS: Only % seats available, but % requested', v_trip.available_seats, p_seats_booked;
  END IF;

  -- 6. منع الحجز المزدوج (إذا كان الراكب لديه حجز معلق أو نشط بالفعل على نفس هذه الرحلة)
  SELECT COUNT(*) INTO v_existing_booking_count
  FROM public.bookings
  WHERE trip_id = p_trip_id 
    AND passenger_id = p_passenger_id
    AND status IN ('pending', 'accepted', 'confirmed', 'arrived', 'started', 'ongoing');

  IF v_existing_booking_count > 0 THEN
    RAISE EXCEPTION 'DUPLICATE_ACTIVE_BOOKING: You already have an active booking on this trip';
  END IF;

  -- 7. حساب السعر الإجمالي بدقة من مصدر الحقيقة
  IF v_trip.is_private THEN
    v_calculated_price := v_trip.price_per_seat;
  ELSE
    v_calculated_price := p_seats_booked * v_trip.price_per_seat;
  END IF;

  -- 8. إدراج الحجز بحالة pending
  INSERT INTO public.bookings (trip_id, passenger_id, seats_booked, total_price, status)
  VALUES (p_trip_id, p_passenger_id, p_seats_booked, v_calculated_price, 'pending')
  RETURNING id INTO v_booking_id;

  RETURN v_booking_id;
END;
$$;

-- 4. تحديث تريجر التحقق والحماية على جدول bookings مباشرة لحماية الإدراج اليدوي/المباشر
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

  -- منع الحجز على الرحلات المنتهية أو الملغاة
  IF v_trip.status IN ('completed', 'cancelled') THEN
    RAISE EXCEPTION 'TRIP_NOT_BOOKABLE: Cannot book a trip with status %', v_trip.status;
  END IF;

  -- منع الحجز على رحلة خاصة انطلقت
  IF v_trip.is_private AND v_trip.status IN ('started', 'ongoing') THEN
    RAISE EXCEPTION 'PRIVATE_TRIP_ALREADY_STARTED: Cannot book an ongoing private trip';
  END IF;

  -- منع السائق من حجز رحلته
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
