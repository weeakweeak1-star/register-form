-- ==============================================================================
-- Migration: Add Promotions and Coupons System
-- Description: Creates tables for promos, user coupons, and alters existing tables
-- ==============================================================================

-- 1. Create Promotions Table
CREATE TABLE IF NOT EXISTS public.promotions (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    discount_type TEXT NOT NULL CHECK (discount_type IN ('PERCENTAGE', 'FIXED_AMOUNT')),
    discount_value NUMERIC NOT NULL,
    max_discount NUMERIC,
    target_trip_type TEXT CHECK (target_trip_type IN ('taxi', 'intercity_private')),
    is_welcome_offer BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::TEXT, now()) NOT NULL
);

ALTER TABLE public.promotions
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS max_total_uses INTEGER,
ADD COLUMN IF NOT EXISTS current_uses INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS min_fare NUMERIC DEFAULT 0;

-- 2. Create User Coupons Table
CREATE TABLE IF NOT EXISTS public.user_coupons (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    promo_id uuid REFERENCES public.promotions(id) ON DELETE CASCADE NOT NULL,
    status TEXT NOT NULL DEFAULT 'AVAILABLE' CHECK (status IN ('AVAILABLE', 'LOCKED', 'USED', 'EXPIRED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::TEXT, now()) NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(user_id, promo_id)
);

-- 3. Alter taxi_requests table to track discounts
ALTER TABLE public.taxi_requests
ADD COLUMN IF NOT EXISTS promo_id uuid REFERENCES public.promotions(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS original_fare NUMERIC,
ADD COLUMN IF NOT EXISTS discount_amount NUMERIC DEFAULT 0;

-- 4. Update transactions type enum constraint to include 'promo_compensation'
ALTER TABLE public.transactions
DROP CONSTRAINT IF EXISTS transactions_type_check;

ALTER TABLE public.transactions
ADD CONSTRAINT transactions_type_check 
CHECK (type IN ('deposit', 'withdrawal', 'fee', 'commission', 'trip_earning', 'trip_payment', 'penalty', 'refund', 'promo_compensation'));

-- 5. Enable RLS
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_coupons ENABLE ROW LEVEL SECURITY;

-- 6. Policies
-- Promotions: Anyone can view active promotions (or at least authenticated users)
DROP POLICY IF EXISTS "Users can view active promotions" ON public.promotions;
CREATE POLICY "Users can view active promotions" ON public.promotions
    FOR SELECT USING (is_active = true);

-- User Coupons: Users can view their own coupons
DROP POLICY IF EXISTS "Users can view their own coupons" ON public.user_coupons;
CREATE POLICY "Users can view their own coupons" ON public.user_coupons
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own coupons" ON public.user_coupons;
CREATE POLICY "Users can update their own coupons" ON public.user_coupons
    FOR UPDATE USING (auth.uid() = user_id);
