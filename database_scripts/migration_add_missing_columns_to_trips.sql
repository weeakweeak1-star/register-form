-- Consolidated migration to fix missing columns in the trips table
-- Run this in the Supabase SQL Editor to resolve "column not found" errors

ALTER TABLE public.trips 
ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT FALSE;

-- We use text[] instead of JSONB for simple lists of strings to avoid syntax errors with 'contains' filter
ALTER TABLE public.trips DROP COLUMN IF EXISTS origin_areas;
ALTER TABLE public.trips DROP COLUMN IF EXISTS destination_areas;
ALTER TABLE public.trips ADD COLUMN origin_areas text[] DEFAULT '{}'::text[];
ALTER TABLE public.trips ADD COLUMN destination_areas text[] DEFAULT '{}'::text[];

-- Refresh PostgREST cache
NOTIFY pgrst, 'reload schema';
