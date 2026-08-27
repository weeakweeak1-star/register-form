-- Full Supabase Schema Setup for "scar" App

-- 1. Create a table for public profiles
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid REFERENCES auth.users NOT NULL PRIMARY KEY,
  email TEXT,
  full_name TEXT,
  phone TEXT UNIQUE,
  avatar_url TEXT,
  rating DOUBLE PRECISION DEFAULT 5.0,
  is_driver BOOLEAN DEFAULT FALSE,
  driver_status TEXT DEFAULT 'approved' CHECK (driver_status IN ('none', 'pending', 'approved', 'suspended', 'rejected')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::TEXT, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::TEXT, now()) NOT NULL
);

-- 2. Create a table for Trips (matching Dart Trip model)
CREATE TABLE IF NOT EXISTS public.trips (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  driver_id uuid REFERENCES public.profiles(id) NOT NULL,
  origin TEXT NOT NULL,
  destination TEXT NOT NULL,
  departure_time TIMESTAMP WITH TIME ZONE NOT NULL,
  price_per_seat NUMERIC NOT NULL,
  total_seats INT NOT NULL,
  available_seats INT NOT NULL,
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'started', 'ongoing', 'completed', 'cancelled')),
  start_lat DOUBLE PRECISION,
  start_lng DOUBLE PRECISION,
  end_lat DOUBLE PRECISION,
  end_lng DOUBLE PRECISION,
  current_lat DOUBLE PRECISION,
  current_lng DOUBLE PRECISION,
  route_polyline TEXT,
  checkpoints JSONB DEFAULT '[]'::JSONB,
  is_private BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::TEXT, now()) NOT NULL
);

-- 3. Create a table for Bookings
CREATE TABLE IF NOT EXISTS public.bookings (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  trip_id uuid REFERENCES public.trips(id) ON DELETE CASCADE NOT NULL,
  passenger_id uuid REFERENCES public.profiles(id) NOT NULL,
  seats_booked INT NOT NULL DEFAULT 1 CHECK (seats_booked > 0),
  total_price NUMERIC NOT NULL CHECK (total_price >= 0),
  pickup_point JSONB,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'confirmed', 'rejected', 'cancelled', 'arrived', 'started', 'ongoing', 'completed')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::TEXT, now()) NOT NULL
);




-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- 5. Create basic policies
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON public.profiles;
CREATE POLICY "Public profiles are viewable by everyone." ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can edit own profile." ON public.profiles;
CREATE POLICY "Users can edit own profile." ON public.profiles FOR ALL USING (auth.uid() = id);

-- 5.2 Helper Functions to prevent RLS Infinite Recursion (Error 42P17)
CREATE OR REPLACE FUNCTION public.check_user_has_booking(p_trip_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.bookings
    WHERE trip_id = p_trip_id AND passenger_id = p_user_id
  );
$$;

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

CREATE OR REPLACE FUNCTION public.check_is_driver(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT is_driver FROM public.profiles WHERE id = p_user_id),
    false
  );
$$;

-- 5.3 Trips Table Secure Policies
DROP POLICY IF EXISTS "Trips are viewable by everyone." ON public.trips;
DROP POLICY IF EXISTS "Drivers can manage their own trips." ON public.trips;
DROP POLICY IF EXISTS "Public trips are viewable for search and booking" ON public.trips;
DROP POLICY IF EXISTS "Drivers can view their own trips" ON public.trips;
DROP POLICY IF EXISTS "Passengers can view trips they booked" ON public.trips;
DROP POLICY IF EXISTS "Drivers can insert their own trips" ON public.trips;
DROP POLICY IF EXISTS "Drivers can update their own trips" ON public.trips;
DROP POLICY IF EXISTS "Drivers can delete their own trips" ON public.trips;

-- أ. السائق يرى جميع رحلاته
CREATE POLICY "Drivers can view their own trips" ON public.trips
    FOR SELECT TO authenticated
    USING (auth.uid() = driver_id);

-- ب. الركاب الذين حجزوا في الرحلة يرون تفاصيلها وموقعها المباشر
CREATE POLICY "Passengers can view trips they booked" ON public.trips
    FOR SELECT TO authenticated
    USING (public.check_user_has_booking(id, auth.uid()));

-- ج. تصفح الرحلات المتاحة للحجز (الخاصة تختفي فور اكتمال حجزها لحماية خصوصية الراكب)
CREATE POLICY "Public trips are viewable for search and booking" ON public.trips
    FOR SELECT TO authenticated
    USING (
        (is_private = false AND status IN ('scheduled', 'started') AND available_seats > 0)
        OR
        (is_private = true AND status = 'scheduled' AND available_seats = total_seats)
    );

-- د. إدراج الرحلات محصور بالسائقين المعتمدين فقط
CREATE POLICY "Drivers can insert their own trips" ON public.trips
    FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = driver_id 
        AND public.check_is_driver(auth.uid()) = true
    );

-- هـ. التعديل والحذف محصور بصاحب الرحلة
CREATE POLICY "Drivers can update their own trips" ON public.trips
    FOR UPDATE TO authenticated
    USING (auth.uid() = driver_id)
    WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "Drivers can delete their own trips" ON public.trips
    FOR DELETE TO authenticated
    USING (auth.uid() = driver_id);

-- 5.4 Bookings Table Secure Policies
DROP POLICY IF EXISTS "Users can manage their own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Users can manage their own bookings." ON public.bookings;
DROP POLICY IF EXISTS "Passengers can view their own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Passengers can insert their own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Passengers can update their own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Passengers can delete their own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Drivers can view bookings for their trips" ON public.bookings;
DROP POLICY IF EXISTS "Drivers can update bookings for their trips" ON public.bookings;

CREATE POLICY "Passengers can view their own bookings" ON public.bookings
    FOR SELECT TO authenticated
    USING (auth.uid() = passenger_id);

CREATE POLICY "Drivers can view bookings for their trips" ON public.bookings
    FOR SELECT TO authenticated
    USING (public.check_is_trip_driver(trip_id, auth.uid()));

CREATE POLICY "Passengers can insert their own bookings" ON public.bookings
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = passenger_id);

CREATE POLICY "Passengers can update their own bookings" ON public.bookings
    FOR UPDATE TO authenticated
    USING (auth.uid() = passenger_id)
    WITH CHECK (auth.uid() = passenger_id);

CREATE POLICY "Drivers can update bookings for their trips" ON public.bookings
    FOR UPDATE TO authenticated
    USING (public.check_is_trip_driver(trip_id, auth.uid()))
    WITH CHECK (public.check_is_trip_driver(trip_id, auth.uid()));

CREATE POLICY "Passengers can delete their own bookings" ON public.bookings
    FOR DELETE TO authenticated
    USING (auth.uid() = passenger_id);



-- 6. Enable Realtime for streaming locations
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
END $$;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND schemaname = 'public' 
    AND tablename = 'trips'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.trips;
  END IF;
END $$;


-- 7. Trigger for auto-profile creation on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, phone, avatar_url, is_driver)
  VALUES (
    new.id, 
    new.email, 
    new.raw_user_meta_data->>'full_name', 
    COALESCE(new.phone, new.raw_user_meta_data->>'phone', new.raw_user_meta_data->>'phone_number'),
    new.raw_user_meta_data->>'avatar_url',
    COALESCE((new.raw_user_meta_data->>'is_driver')::BOOLEAN, FALSE)
  )
  ON CONFLICT (id) DO UPDATE SET
    phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
    email = COALESCE(EXCLUDED.email, public.profiles.email);
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 8. Booking Function: Decrement Available Seats
CREATE OR REPLACE FUNCTION public.decrement_seats(trip_id uuid, seats int)
RETURNS void AS $$
BEGIN
  UPDATE public.trips
  SET available_seats = available_seats - seats
  WHERE id = trip_id AND available_seats >= seats;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Not enough seats available';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Booking Function: Increment Available Seats (for cancellations/rejections)
CREATE OR REPLACE FUNCTION public.increment_seats(trip_id uuid, seats int)
RETURNS void AS $$
BEGIN
  UPDATE public.trips
  SET available_seats = available_seats + seats
  WHERE id = trip_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. Table for storing user FCM device tokens (Multi-device push notifications)
CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL UNIQUE,
    device_type TEXT DEFAULT 'android',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::TEXT, now()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::TEXT, now()) NOT NULL
);

ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own tokens" ON public.user_fcm_tokens;
CREATE POLICY "Users can manage own tokens" ON public.user_fcm_tokens
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user_id ON public.user_fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_token ON public.user_fcm_tokens(fcm_token);

-- 11. Trigger to validate and calculate total_price for bookings automatically
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

-- 12. Ratings Table & Profile Rating Calculation Trigger
CREATE TABLE IF NOT EXISTS public.ratings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    rater_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    ratee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    trip_id UUID REFERENCES public.trips(id) ON DELETE SET NULL,
    booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
    taxi_request_id UUID REFERENCES public.taxi_requests(id) ON DELETE SET NULL,
    score INT NOT NULL CHECK (score >= 1 AND score <= 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::TEXT, now()) NOT NULL,
    CONSTRAINT ratings_no_self_rating CHECK (rater_id <> ratee_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_ratings_booking_rater 
ON public.ratings(booking_id, rater_id) 
WHERE booking_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_ratings_taxi_rater 
ON public.ratings(taxi_request_id, rater_id) 
WHERE taxi_request_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ratings_ratee_id ON public.ratings(ratee_id);
CREATE INDEX IF NOT EXISTS idx_ratings_rater_id ON public.ratings(rater_id);
CREATE INDEX IF NOT EXISTS idx_ratings_trip_id ON public.ratings(trip_id);

ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ratings are viewable by authenticated users" ON public.ratings;
CREATE POLICY "Ratings are viewable by authenticated users" ON public.ratings
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Users can insert their own ratings" ON public.ratings;
CREATE POLICY "Users can insert their own ratings" ON public.ratings
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = rater_id AND rater_id <> ratee_id);

CREATE OR REPLACE FUNCTION public.update_profile_rating()
RETURNS TRIGGER AS $$
DECLARE
  v_target_user_id UUID;
  v_avg_rating DOUBLE PRECISION;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_target_user_id := OLD.ratee_id;
  ELSE
    v_target_user_id := NEW.ratee_id;
  END IF;

  SELECT COALESCE(ROUND(AVG(score)::numeric, 2), 5.0)
  INTO v_avg_rating
  FROM public.ratings
  WHERE ratee_id = v_target_user_id;

  UPDATE public.profiles
  SET rating = v_avg_rating
  WHERE id = v_target_user_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_update_profile_rating ON public.ratings;
CREATE TRIGGER tr_update_profile_rating
AFTER INSERT OR UPDATE OR DELETE ON public.ratings
FOR EACH ROW EXECUTE FUNCTION public.update_profile_rating();

-- 13. Taxi Requests Table & Secure RLS Policies
CREATE TABLE IF NOT EXISTS public.taxi_requests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    passenger_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    pickup_lat DOUBLE PRECISION NOT NULL,
    pickup_lng DOUBLE PRECISION NOT NULL,
    pickup_address TEXT NOT NULL,
    dropoff_lat DOUBLE PRECISION NOT NULL,
    dropoff_lng DOUBLE PRECISION NOT NULL,
    dropoff_address TEXT NOT NULL,
    price DOUBLE PRECISION NOT NULL CHECK (price > 0),
    status TEXT NOT NULL DEFAULT 'searching' CHECK (status IN ('searching', 'accepted', 'arrived', 'ongoing', 'completed', 'cancelled')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT taxi_requests_coords_check CHECK (
        pickup_lat BETWEEN -90 AND 90 AND 
        pickup_lng BETWEEN -180 AND 180 AND 
        dropoff_lat BETWEEN -90 AND 90 AND 
        dropoff_lng BETWEEN -180 AND 180
    )
);

ALTER TABLE public.taxi_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "taxi_requests is viewable by everyone" ON public.taxi_requests;
CREATE POLICY "taxi_requests is viewable by everyone" ON public.taxi_requests
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "passengers can insert their own requests" ON public.taxi_requests;
CREATE POLICY "passengers can insert their own requests" ON public.taxi_requests
    FOR INSERT WITH CHECK (auth.uid() = passenger_id);

DROP POLICY IF EXISTS "users can update their own requests or drivers can accept them" ON public.taxi_requests;
DROP POLICY IF EXISTS "passengers can update own requests" ON public.taxi_requests;
CREATE POLICY "passengers can update own requests" ON public.taxi_requests
    FOR UPDATE TO authenticated
    USING (auth.uid() = passenger_id)
    WITH CHECK (auth.uid() = passenger_id);

DROP POLICY IF EXISTS "assigned drivers can update requests" ON public.taxi_requests;
CREATE POLICY "assigned drivers can update requests" ON public.taxi_requests
    FOR UPDATE TO authenticated
    USING (auth.uid() = driver_id)
    WITH CHECK (auth.uid() = driver_id);

DROP POLICY IF EXISTS "drivers can accept searching requests" ON public.taxi_requests;
CREATE POLICY "drivers can accept searching requests" ON public.taxi_requests
    FOR UPDATE TO authenticated
    USING (
        status = 'searching' 
        AND driver_id IS NULL
        AND auth.uid() <> passenger_id
        AND EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND is_driver = true
        )
    )
    WITH CHECK (
        driver_id = auth.uid()
        AND status = 'accepted'
    );

CREATE OR REPLACE FUNCTION public.accept_taxi_request(p_request_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id UUID;
  v_is_driver BOOLEAN;
  v_request RECORD;
BEGIN
  v_driver_id := auth.uid();
  
  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  SELECT is_driver INTO v_is_driver
  FROM public.profiles
  WHERE id = v_driver_id;

  IF v_is_driver IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_A_DRIVER');
  END IF;

  SELECT id, passenger_id, status, driver_id
  INTO v_request
  FROM public.taxi_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'REQUEST_NOT_FOUND');
  END IF;

  IF v_request.passenger_id = v_driver_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'CANNOT_ACCEPT_OWN_REQUEST');
  END IF;

  IF v_request.status <> 'searching' OR v_request.driver_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'ALREADY_TAKEN');
  END IF;

  UPDATE public.taxi_requests
  SET driver_id = v_driver_id,
      status = 'accepted',
      updated_at = NOW()
  WHERE id = p_request_id;

  RETURN jsonb_build_object('success', true, 'request_id', p_request_id);
END;
$$;

-- 14. OTP Rate Limiting Table & Stored Verification Function
CREATE TABLE IF NOT EXISTS public.otp_rate_limits (
    phone TEXT PRIMARY KEY,
    attempts_in_hour INT DEFAULT 1,
    first_attempt_in_hour TIMESTAMPTZ DEFAULT NOW(),
    last_attempt_at TIMESTAMPTZ DEFAULT NOW(),
    blocked_until TIMESTAMPTZ,
    daily_attempts INT DEFAULT 1,
    first_attempt_in_day TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.otp_rate_limits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Deny direct user access to otp_rate_limits" ON public.otp_rate_limits;
CREATE POLICY "Deny direct user access to otp_rate_limits" ON public.otp_rate_limits
    FOR ALL USING (false);

CREATE OR REPLACE FUNCTION public.check_and_record_otp_attempt(p_phone TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_record RECORD;
  v_now TIMESTAMPTZ := NOW();
  v_cooldown_seconds INT := 60;
  v_max_hourly_attempts INT := 5;
  v_max_daily_attempts INT := 10;
  v_seconds_since_last INT;
  v_clean_phone TEXT;
BEGIN
  v_clean_phone := TRIM(p_phone);
  
  IF v_clean_phone IS NULL OR LENGTH(v_clean_phone) < 8 THEN
    RETURN jsonb_build_object('allowed', false, 'error', 'INVALID_PHONE');
  END IF;

  SELECT * INTO v_record
  FROM public.otp_rate_limits
  WHERE phone = v_clean_phone
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.otp_rate_limits (phone, attempts_in_hour, first_attempt_in_hour, last_attempt_at, daily_attempts, first_attempt_in_day)
    VALUES (v_clean_phone, 1, v_now, v_now, 1, v_now);
    
    RETURN jsonb_build_object('allowed', true);
  END IF;

  IF v_record.blocked_until IS NOT NULL AND v_record.blocked_until > v_now THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'error', 'BLOCKED',
      'retry_after_seconds', EXTRACT(EPOCH FROM (v_record.blocked_until - v_now))::INT
    );
  END IF;

  v_seconds_since_last := EXTRACT(EPOCH FROM (v_now - v_record.last_attempt_at))::INT;
  IF v_seconds_since_last < v_cooldown_seconds THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'error', 'COOLDOWN',
      'retry_after_seconds', (v_cooldown_seconds - v_seconds_since_last)
    );
  END IF;

  IF v_now - v_record.first_attempt_in_hour > INTERVAL '1 hour' THEN
    v_record.attempts_in_hour := 0;
    v_record.first_attempt_in_hour := v_now;
  END IF;

  IF v_now - v_record.first_attempt_in_day > INTERVAL '24 hours' THEN
    v_record.daily_attempts := 0;
    v_record.first_attempt_in_day := v_now;
  END IF;

  IF v_record.attempts_in_hour >= v_max_hourly_attempts THEN
    UPDATE public.otp_rate_limits
    SET blocked_until = v_now + INTERVAL '1 hour',
        last_attempt_at = v_now
    WHERE phone = v_clean_phone;
    
    RETURN jsonb_build_object(
      'allowed', false,
      'error', 'HOURLY_LIMIT_EXCEEDED',
      'retry_after_seconds', 3600
    );
  END IF;

  IF v_record.daily_attempts >= v_max_daily_attempts THEN
    UPDATE public.otp_rate_limits
    SET blocked_until = v_now + INTERVAL '12 hours',
        last_attempt_at = v_now
    WHERE phone = v_clean_phone;
    
    RETURN jsonb_build_object(
      'allowed', false,
      'error', 'DAILY_LIMIT_EXCEEDED',
      'retry_after_seconds', 43200
    );
  END IF;

  UPDATE public.otp_rate_limits
  SET attempts_in_hour = v_record.attempts_in_hour + 1,
      daily_attempts = v_record.daily_attempts + 1,
      last_attempt_at = v_now,
      first_attempt_in_hour = v_record.first_attempt_in_hour,
      first_attempt_in_day = v_record.first_attempt_in_day,
      blocked_until = NULL
  WHERE phone = v_clean_phone;

  RETURN jsonb_build_object('allowed', true);
END;
$$;

-- 15. Profile Guard Trigger: Protects Sensitive Fields (Rating, Verification Role)
CREATE OR REPLACE FUNCTION public.guard_profile_sensitive_fields()
RETURNS TRIGGER AS $$
BEGIN
  -- منع تعديل التقييم يدوياً من جهة العميل
  IF TG_OP = 'UPDATE' AND NEW.rating IS DISTINCT FROM OLD.rating THEN
    IF pg_trigger_depth() <= 1 THEN
      NEW.rating := OLD.rating;
    END IF;
  END IF;

  -- منع رفع رتبة الحساب إلى معتمد بدون إذن
  IF TG_OP = 'UPDATE' AND OLD.driver_status IN ('suspended', 'rejected', 'pending') AND NEW.driver_status = 'approved' THEN
    IF pg_trigger_depth() <= 1 THEN
      NEW.driver_status := OLD.driver_status;
    END IF;
  END IF;

  -- مزامنة الدور إلى JWT App Metadata
  IF NEW.is_driver IS DISTINCT FROM OLD.is_driver OR NEW.driver_status IS DISTINCT FROM OLD.driver_status THEN
    BEGIN
      UPDATE auth.users
      SET raw_app_meta_data = raw_app_meta_data || 
          jsonb_build_object(
            'role', CASE WHEN NEW.is_driver THEN 'driver' ELSE 'passenger' END,
            'driver_status', NEW.driver_status
          )
      WHERE id = NEW.id;
    EXCEPTION WHEN OTHERS THEN
    END;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

DROP TRIGGER IF EXISTS tr_guard_profile_sensitive_fields ON public.profiles;
CREATE TRIGGER tr_guard_profile_sensitive_fields
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.guard_profile_sensitive_fields();




