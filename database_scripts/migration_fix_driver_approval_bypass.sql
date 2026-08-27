-- ==============================================================================
-- Migration: Fix Driver Approval Bypass (Strict Enforcement)
-- ==============================================================================

-- 1. Alter the default value of driver_status to 'none' instead of 'approved'
ALTER TABLE public.profiles ALTER COLUMN driver_status SET DEFAULT 'none';

-- 2. Update the profile trigger to handle BOTH INSERT AND UPDATE
-- This guarantees that anytime a profile is created or updated, its driver_status is validated.
CREATE OR REPLACE FUNCTION public.handle_approved_driver()
RETURNS TRIGGER AS $$
DECLARE
  app_record RECORD;
BEGIN
  -- Match by comparing the last 10 digits (ignoring +964 vs 07)
  SELECT * INTO app_record FROM public.driver_applications 
  WHERE RIGHT(phone_number, 10) = RIGHT(NEW.phone, 10) 
  ORDER BY created_at DESC LIMIT 1;
  
  IF FOUND THEN
    IF app_record.status = 'approved' THEN
      NEW.is_driver := true;
      NEW.driver_status := 'approved';
      NEW.full_name := COALESCE(app_record.full_name, NEW.full_name);
      NEW.car_type := COALESCE(app_record.car_type, NEW.car_type);
      NEW.car_model := COALESCE(app_record.car_model, NEW.car_model);
      NEW.car_color := COALESCE(app_record.car_color, NEW.car_color);
      NEW.car_plate := COALESCE(app_record.car_plate, NEW.car_plate);
      NEW.car_seats := COALESCE(app_record.car_seats, NEW.car_seats);
    ELSIF app_record.status = 'pending' THEN
      NEW.driver_status := 'pending';
    ELSIF app_record.status = 'rejected' THEN
      NEW.driver_status := 'rejected';
    ELSE 
      NEW.driver_status := 'none';
      NEW.is_driver := false;
    END IF;
  ELSE
    -- No application found. Prevent auto-approval if the app incorrectly sends it.
    IF NEW.is_driver = true AND (OLD IS NULL OR OLD.driver_status NOT IN ('approved', 'pending', 'rejected')) THEN
        NEW.driver_status := 'none';
        NEW.is_driver := false;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach it to BOTH INSERT and UPDATE
DROP TRIGGER IF EXISTS on_profile_created_driver ON public.profiles;
CREATE TRIGGER on_profile_created_driver
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE PROCEDURE public.handle_approved_driver();


-- 3. Update the sync trigger from driver_applications to profiles
CREATE OR REPLACE FUNCTION public.sync_approved_application_to_profile()
RETURNS TRIGGER AS $$
BEGIN
  -- Sync any status change ('pending', 'approved', 'rejected') immediately to profiles
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    UPDATE public.profiles
    SET 
      is_driver = CASE WHEN NEW.status = 'approved' THEN true ELSE is_driver END,
      driver_status = NEW.status,
      full_name = COALESCE(NEW.full_name, full_name),
      car_type = COALESCE(NEW.car_type, car_type),
      car_model = COALESCE(NEW.car_model, car_model),
      car_color = COALESCE(NEW.car_color, car_color),
      car_plate = COALESCE(NEW.car_plate, car_plate),
      car_seats = COALESCE(NEW.car_seats, car_seats)
    WHERE RIGHT(phone, 10) = RIGHT(NEW.phone_number, 10);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- The trigger is already attached as tr_sync_approved_application_to_profile or similar in previous migrations.
-- We ensure it triggers after update.
DROP TRIGGER IF EXISTS tr_sync_approved_application_to_profile ON public.driver_applications;
CREATE TRIGGER tr_sync_approved_application_to_profile
  AFTER UPDATE ON public.driver_applications
  FOR EACH ROW EXECUTE PROCEDURE public.sync_approved_application_to_profile();


-- 4. Clean up corrupted data
-- Any profile that has driver_status='approved' but its application is not approved
UPDATE public.profiles p
SET driver_status = a.status
FROM public.driver_applications a
WHERE RIGHT(p.phone, 10) = RIGHT(a.phone_number, 10)
  AND p.driver_status != a.status;
