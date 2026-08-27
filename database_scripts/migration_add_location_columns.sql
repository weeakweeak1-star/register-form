-- Migration Script: Add location columns to profiles table
-- Run this if you encounter errors about missing 'last_known_lat' or 'last_known_lng' columns

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS last_known_lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS last_known_lng DOUBLE PRECISION;

-- Optional: Create an index for faster location-based queries
CREATE INDEX IF NOT EXISTS profiles_location_idx ON public.profiles (last_known_lat, last_known_lng);
