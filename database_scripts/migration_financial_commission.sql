-- 1. Helper function to deduct commission securely
CREATE OR REPLACE FUNCTION public.process_driver_commission(p_driver_id UUID, p_amount NUMERIC, p_trip_id UUID, p_booking_id UUID, p_taxi_request_id UUID)
RETURNS VOID AS $$
DECLARE
  v_commission NUMERIC;
BEGIN
  -- 10% commission
  v_commission := p_amount * 0.10;
  
  -- Ensure wallet exists
  INSERT INTO public.driver_wallets (driver_id, balance)
  VALUES (p_driver_id, 0)
  ON CONFLICT (driver_id) DO NOTHING;
  
  -- Deduct from wallet
  UPDATE public.driver_wallets
  SET balance = balance - v_commission,
      updated_at = NOW()
  WHERE driver_id = p_driver_id;
  
  -- Record transaction
  INSERT INTO public.transactions (user_id, driver_id, amount, type, provider, status, trip_id, booking_id, taxi_request_id)
  VALUES (p_driver_id, p_driver_id, -v_commission, 'commission', 'system', 'success', p_trip_id, p_booking_id, p_taxi_request_id);
  
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Trigger for Taxi Requests
CREATE OR REPLACE FUNCTION public.trigger_taxi_commission()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    PERFORM public.process_driver_commission(NEW.driver_id, NEW.price::NUMERIC, NULL, NULL, NEW.id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_taxi_commission ON public.taxi_requests;
CREATE TRIGGER tr_taxi_commission
AFTER UPDATE ON public.taxi_requests
FOR EACH ROW
EXECUTE FUNCTION public.trigger_taxi_commission();

-- 3. Trigger for Bookings (Shared/Private)
CREATE OR REPLACE FUNCTION public.trigger_booking_commission()
RETURNS TRIGGER AS $$
DECLARE
  v_driver_id UUID;
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    -- Get driver_id from the trip
    SELECT driver_id INTO v_driver_id FROM public.trips WHERE id = NEW.trip_id;
    
    IF FOUND THEN
      PERFORM public.process_driver_commission(v_driver_id, NEW.total_price, NEW.trip_id, NEW.id, NULL);
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_booking_commission ON public.bookings;
CREATE TRIGGER tr_booking_commission
AFTER UPDATE ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.trigger_booking_commission();

-- 4. Enforce Balance Limit on accepting taxi request
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
  v_balance NUMERIC;
BEGIN
  v_driver_id := auth.uid();
  
  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  SELECT is_driver INTO v_is_driver
  FROM public.profiles
  WHERE id = v_driver_id;

  IF NOT v_is_driver THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_A_DRIVER');
  END IF;
  
  -- CHECK BALANCE LIMIT
  SELECT balance INTO v_balance FROM public.driver_wallets WHERE driver_id = v_driver_id;
  IF v_balance IS NOT NULL AND v_balance <= -5000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'INSUFFICIENT_BALANCE');
  END IF;

  SELECT * INTO v_request
  FROM public.taxi_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'REQUEST_NOT_FOUND');
  END IF;

  IF v_request.status != 'searching' THEN
    RETURN jsonb_build_object('success', false, 'error', 'REQUEST_NOT_AVAILABLE');
  END IF;
  
  IF v_request.passenger_id = v_driver_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'CANNOT_ACCEPT_OWN_REQUEST');
  END IF;

  UPDATE public.taxi_requests
  SET driver_id = v_driver_id,
      status = 'accepted',
      updated_at = NOW()
  WHERE id = p_request_id;

  RETURN jsonb_build_object('success', true);
END;
$$;
