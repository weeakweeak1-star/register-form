-- ==============================================================================
-- Migration: Insert Welcome Promotion
-- Description: Creates the default 100% discount welcome offer in the database
-- ==============================================================================

INSERT INTO public.promotions (code, discount_type, discount_value, max_discount, target_trip_type, is_welcome_offer, is_active)
VALUES ('WELCOME100', 'PERCENTAGE', 100, NULL, 'taxi', true, true)
ON CONFLICT (code) DO NOTHING;
