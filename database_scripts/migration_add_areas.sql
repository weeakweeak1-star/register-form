-- Migration to add nearby areas to trips table
ALTER TABLE public.trips 
ADD COLUMN IF NOT EXISTS origin_areas JSONB DEFAULT '[]'::JSONB,
ADD COLUMN IF NOT EXISTS destination_areas JSONB DEFAULT '[]'::JSONB;
