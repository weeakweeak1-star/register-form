-- Add rating column to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS rating DOUBLE PRECISION DEFAULT 5.0;

-- Optional: Create a function to update rating (for future use)
-- This would be called when a driver rates a passenger
