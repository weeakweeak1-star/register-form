
-- Fix bad data in bookings table where pickup_point is a number/string instead of JSON object
UPDATE public.bookings 
SET pickup_point = NULL 
WHERE jsonb_typeof(pickup_point) <> 'object';

-- Ensure future inserts of pickup_point are valid JSON objects or NULL
ALTER TABLE public.bookings 
ADD CONSTRAINT check_pickup_point_is_object 
CHECK (pickup_point IS NULL OR jsonb_typeof(pickup_point) = 'object');
