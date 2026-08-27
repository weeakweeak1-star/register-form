-- ==============================================================================
-- Migration: Validate and Enforce total_price = seats_booked * price_per_seat
-- ==============================================================================

-- 1. إضافة قيود فحص (CHECK Constraints) على جدول الحجوزات
ALTER TABLE public.bookings
DROP CONSTRAINT IF EXISTS bookings_seats_booked_check,
DROP CONSTRAINT IF EXISTS bookings_total_price_check;

ALTER TABLE public.bookings
ADD CONSTRAINT bookings_seats_booked_check CHECK (seats_booked > 0),
ADD CONSTRAINT bookings_total_price_check CHECK (total_price >= 0);

-- 2. إنشاء دالة Trigger لحساب والتحقق من السعر الإجمالي تلقائياً
-- هذه الدالة تحمي النظام وتضمن أن total_price يُحسب بدقة من قاعدة البيانات
-- بناءً على عدد المقاعد المحجوزة وسعر المقعد في جدول الرحلات (أو السعر الثابت للرحلة الخاصة)
CREATE OR REPLACE FUNCTION public.calculate_and_validate_booking_total_price()
RETURNS TRIGGER AS $$
DECLARE
  v_trip RECORD;
  v_expected_price NUMERIC;
BEGIN
  -- جلب بيانات الرحلة الأساسية
  SELECT id, price_per_seat, is_private, total_seats, available_seats, status
  INTO v_trip
  FROM public.trips
  WHERE id = NEW.trip_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'TRIP_NOT_FOUND: Trip with ID % does not exist', NEW.trip_id;
  END IF;

  -- منع الحجز على الرحلات الملغاة أو المنتهية
  IF v_trip.status IN ('completed', 'cancelled') THEN
    RAISE EXCEPTION 'TRIP_NOT_BOOKABLE: Cannot book a trip with status %', v_trip.status;
  END IF;

  -- التحقق من عدد المقاعد
  IF NEW.seats_booked IS NULL OR NEW.seats_booked <= 0 THEN
    RAISE EXCEPTION 'INVALID_SEATS: seats_booked must be greater than 0';
  END IF;

  -- حساب السعر الإجمالي بدقة من قاعدة البيانات
  IF v_trip.is_private THEN
    -- في الرحلة الخاصة (حجز السيارة بالكامل)، السعر الإجمالي هو سعر السيارة المحدد في price_per_seat
    v_expected_price := v_trip.price_per_seat;
  ELSE
    -- في الرحلة التشاركية: السعر = عدد المقاعد × سعر المقعد الواحد
    v_expected_price := NEW.seats_booked * v_trip.price_per_seat;
  END IF;

  -- تعيين السعر الإجمالي الصحيح في السجل قبل الحفظ
  NEW.total_price := v_expected_price;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. ربط التريجر بجدول bookings قبل الإضافة أو التعديل
DROP TRIGGER IF EXISTS tr_validate_and_calculate_booking_price ON public.bookings;
CREATE TRIGGER tr_validate_and_calculate_booking_price
BEFORE INSERT OR UPDATE OF seats_booked, trip_id ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.calculate_and_validate_booking_total_price();

-- 4. تحديث دالة RPC create_booking لتطبيق نفس الحسابات والأمان
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
BEGIN
  -- قفل صف الرحلة للتحقق من المقاعد والحالة ومنع التعارض
  SELECT id, available_seats, price_per_seat, is_private, total_seats, status
  INTO v_trip
  FROM public.trips
  WHERE id = p_trip_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'TRIP_NOT_FOUND';
  END IF;

  IF v_trip.status IN ('completed', 'cancelled') THEN
    RAISE EXCEPTION 'TRIP_NOT_BOOKABLE';
  END IF;

  IF v_trip.available_seats < p_seats_booked THEN
    RAISE EXCEPTION 'NOT_ENOUGH_SEATS';
  END IF;

  -- حساب السعر من مصدر الحقيقة في قاعدة البيانات
  IF v_trip.is_private THEN
    v_calculated_price := v_trip.price_per_seat;
  ELSE
    v_calculated_price := p_seats_booked * v_trip.price_per_seat;
  END IF;

  -- إدراج الحجز بالسعر المحسوب وحالة معلقة
  INSERT INTO public.bookings (trip_id, passenger_id, seats_booked, total_price, status)
  VALUES (p_trip_id, p_passenger_id, p_seats_booked, v_calculated_price, 'pending')
  RETURNING id INTO v_booking_id;

  RETURN v_booking_id;
END;
$$;
