-- Add missing total_price column to bookings table
ALTER TABLE public.bookings 
ADD COLUMN IF NOT EXISTS total_price NUMERIC NOT NULL DEFAULT 0;

-- Optional: Refresh schema cache advice (usually handled automatically by Supabase/Postgrest)
-- NOTIFY pgrst, 'reload config'; 
