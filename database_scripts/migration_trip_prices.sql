-- ==============================================================================
-- Migration: Create Governorate Prices Table
-- Description: Creates a table to store fixed prices for shared trips between governorates
-- ==============================================================================

-- 1. Create table
CREATE TABLE IF NOT EXISTS public.governorate_prices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    origin TEXT NOT NULL,
    destination TEXT NOT NULL,
    price NUMERIC NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    UNIQUE(origin, destination)
);

-- 2. Add comments
COMMENT ON TABLE public.governorate_prices IS 'Stores predefined recommended prices for shared trips between governorates.';
COMMENT ON COLUMN public.governorate_prices.origin IS 'Origin governorate English key (e.g., baghdad)';
COMMENT ON COLUMN public.governorate_prices.destination IS 'Destination governorate English key (e.g., karbala)';
COMMENT ON COLUMN public.governorate_prices.price IS 'The recommended price for a single seat in IQD';

-- 3. Enable RLS
ALTER TABLE public.governorate_prices ENABLE ROW LEVEL SECURITY;

-- 4. Create Policies
-- Allow anyone (or authenticated users) to read the prices
CREATE POLICY "Allow public read access to governorate_prices"
    ON public.governorate_prices FOR SELECT
    USING (true);

-- Note: No INSERT/UPDATE/DELETE policies are created for standard users.
-- Prices should only be managed via Supabase Dashboard or by admins (service role).
