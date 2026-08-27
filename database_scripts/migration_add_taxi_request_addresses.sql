-- ==============================================================================
-- Migration: Add missing address and category columns to taxi_requests
-- هذا السكربت يحل خطأ:
-- PostgrestException(message: Could not find the 'dropoff_address' column of 'taxi_requests' in the schema cache, code: PGRST204)
-- ==============================================================================

-- 1. إضافة الأعمدة المطلوبة إلى جدول taxi_requests
ALTER TABLE public.taxi_requests 
ADD COLUMN IF NOT EXISTS pickup_address TEXT,
ADD COLUMN IF NOT EXISTS dropoff_address TEXT,
ADD COLUMN IF NOT EXISTS category TEXT;

-- 2. تحديث الكاش (Reload PostgREST Schema Cache)
NOTIFY pgrst, 'reload schema';
