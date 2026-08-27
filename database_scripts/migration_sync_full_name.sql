-- 1. Update the trigger that runs BEFORE INSERT ON profiles
CREATE OR REPLACE FUNCTION public.handle_approved_driver()
RETURNS TRIGGER AS $$
DECLARE
  app_record RECORD;
BEGIN
  -- Match by comparing the last 10 digits (ignoring +964 vs 07)
  SELECT * INTO app_record FROM public.driver_applications 
  WHERE RIGHT(phone_number, 10) = RIGHT(NEW.phone, 10) AND status = 'approved' LIMIT 1;
  
  IF FOUND THEN
    NEW.is_driver := true;
    NEW.driver_status := 'approved';
    NEW.full_name := app_record.full_name;
    NEW.car_type := app_record.car_type;
    NEW.car_model := app_record.car_model;
    NEW.car_color := app_record.car_color;
    NEW.car_plate := app_record.car_plate;
    NEW.car_seats := app_record.car_seats;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Update the trigger that runs AFTER UPDATE ON driver_applications
CREATE OR REPLACE FUNCTION public.sync_approved_application_to_profile()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'approved' AND OLD.status != 'approved' THEN
    UPDATE public.profiles
    SET 
      is_driver = true,
      driver_status = 'approved',
      full_name = NEW.full_name,
      car_type = NEW.car_type,
      car_model = NEW.car_model,
      car_color = NEW.car_color,
      car_plate = NEW.car_plate,
      car_seats = NEW.car_seats
    WHERE RIGHT(phone, 10) = RIGHT(NEW.phone_number, 10);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Fix the existing profiles that have mismatched names
UPDATE public.profiles p
SET full_name = a.full_name
FROM public.driver_applications a
WHERE RIGHT(p.phone, 10) = RIGHT(a.phone_number, 10)
  AND a.status = 'approved'
  AND p.full_name != a.full_name;
