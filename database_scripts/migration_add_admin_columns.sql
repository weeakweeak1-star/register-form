-- 1. Add car columns to profiles (so drivers have their car info)
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS car_type TEXT,
ADD COLUMN IF NOT EXISTS car_model TEXT,
ADD COLUMN IF NOT EXISTS car_color TEXT,
ADD COLUMN IF NOT EXISTS car_plate TEXT;

-- 2. Add car columns to driver_applications (filled by Admin upon approval)
ALTER TABLE public.driver_applications
ADD COLUMN IF NOT EXISTS car_type TEXT,
ADD COLUMN IF NOT EXISTS car_model TEXT,
ADD COLUMN IF NOT EXISTS car_color TEXT,
ADD COLUMN IF NOT EXISTS car_plate TEXT;

-- 3. Create Trigger to auto-activate driver when they log in for the first time
CREATE OR REPLACE FUNCTION public.handle_approved_driver()
RETURNS TRIGGER AS $$
DECLARE
  app_record RECORD;
BEGIN
  -- If phone matches an approved application, auto-activate driver
  SELECT * INTO app_record FROM public.driver_applications 
  WHERE phone_number = NEW.phone AND status = 'approved' LIMIT 1;
  
  IF FOUND THEN
    NEW.is_driver := true;
    NEW.driver_status := 'active';
    NEW.car_type := app_record.car_type;
    NEW.car_model := app_record.car_model;
    NEW.car_color := app_record.car_color;
    NEW.car_plate := app_record.car_plate;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_profile_created_driver ON public.profiles;
CREATE TRIGGER on_profile_created_driver
  BEFORE INSERT ON public.profiles
  FOR EACH ROW EXECUTE PROCEDURE public.handle_approved_driver();
