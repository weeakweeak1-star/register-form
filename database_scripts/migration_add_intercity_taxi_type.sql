-- ==============================================================================
-- Migration: Add Intercity Private Type to Taxi Requests
-- Description: Extends the taxi_requests table to support instant intercity private trips
-- ==============================================================================

-- 1. Add new columns
ALTER TABLE public.taxi_requests 
ADD COLUMN IF NOT EXISTS trip_type TEXT NOT NULL DEFAULT 'taxi' CHECK (trip_type IN ('taxi', 'intercity_private')),
ADD COLUMN IF NOT EXISTS origin_governorate TEXT,
ADD COLUMN IF NOT EXISTS destination_governorate TEXT;

-- 2. Add Comments
COMMENT ON COLUMN public.taxi_requests.trip_type IS 'Type of the request: taxi (city) or intercity_private (full car between governorates)';
COMMENT ON COLUMN public.taxi_requests.origin_governorate IS 'Origin governorate (only required for intercity_private)';
COMMENT ON COLUMN public.taxi_requests.destination_governorate IS 'Destination governorate (only required for intercity_private)';

-- 3. Add constraint to ensure governorates are provided for intercity trips
ALTER TABLE public.taxi_requests
DROP CONSTRAINT IF EXISTS taxi_requests_intercity_govs_check;

ALTER TABLE public.taxi_requests
ADD CONSTRAINT taxi_requests_intercity_govs_check 
CHECK (
    (trip_type = 'taxi') 
    OR 
    (trip_type = 'intercity_private' AND origin_governorate IS NOT NULL AND destination_governorate IS NOT NULL)
);
