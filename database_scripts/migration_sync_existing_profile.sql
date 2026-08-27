-- Trigger to update existing profile when Admin approves an application
CREATE OR REPLACE FUNCTION public.sync_approved_application_to_profile()
RETURNS TRIGGER AS $$
BEGIN
  -- Only act when status changes to 'approved'
  IF NEW.status = 'approved' AND OLD.status != 'approved' THEN
    -- Try to update the profile if it already exists in the database
    UPDATE public.profiles
    SET 
      is_driver = true,
      driver_status = 'active',
      car_type = NEW.car_type,
      car_model = NEW.car_model,
      car_color = NEW.car_color,
      car_plate = NEW.car_plate
    WHERE phone = NEW.phone_number;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_application_approved ON public.driver_applications;
CREATE TRIGGER on_application_approved
  AFTER UPDATE ON public.driver_applications
  FOR EACH ROW EXECUTE PROCEDURE public.sync_approved_application_to_profile();
