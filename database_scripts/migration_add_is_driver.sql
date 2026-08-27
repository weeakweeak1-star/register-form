-- Migration Script: Add is_driver column to existing profiles table
-- Run this ONLY if you already created the profiles table without is_driver column

-- 1. Add is_driver column to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS is_driver BOOLEAN DEFAULT FALSE;

-- 2. Update the trigger function to include is_driver
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, avatar_url, is_driver)
  VALUES (
    new.id, 
    new.email, 
    new.raw_user_meta_data->>'full_name', 
    new.raw_user_meta_data->>'avatar_url',
    COALESCE((new.raw_user_meta_data->>'is_driver')::BOOLEAN, FALSE)
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    avatar_url = EXCLUDED.avatar_url,
    is_driver = EXCLUDED.is_driver;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. (Optional) If you want to manually set a user as driver, run:
-- UPDATE public.profiles SET is_driver = TRUE WHERE email = 'your-email@example.com';
