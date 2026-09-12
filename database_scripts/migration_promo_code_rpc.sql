-- ==============================================================================
-- Migration: Add Apply Promo Code RPC
-- Description: Allows a user to apply a promo code manually
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.apply_promo_code(
    p_passenger_id uuid,
    p_promo_code text
)
RETURNS jsonb AS $$
DECLARE
    v_promo RECORD;
    v_already_has BOOLEAN;
BEGIN
    -- 1. Find the promo
    SELECT * INTO v_promo FROM public.promotions 
    WHERE code = UPPER(p_promo_code) 
      AND is_active = true 
      AND (expires_at IS NULL OR expires_at > now())
      AND (max_total_uses IS NULL OR current_uses < max_total_uses)
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الكود الترويجي غير صحيح أو منتهي الصلاحية');
    END IF;

    -- 2. Check if user already claimed it
    SELECT EXISTS (
        SELECT 1 FROM public.user_coupons 
        WHERE user_id = p_passenger_id AND promo_id = v_promo.id
    ) INTO v_already_has;

    IF v_already_has THEN
        RETURN jsonb_build_object('success', false, 'message', 'لقد قمت باستخدام هذا الكود أو إضافته لحسابك مسبقاً');
    END IF;

    -- 3. Add to user_coupons
    INSERT INTO public.user_coupons (user_id, promo_id, status)
    VALUES (p_passenger_id, v_promo.id, 'AVAILABLE');

    RETURN jsonb_build_object('success', true, 'message', 'تم إضافة الخصم بنجاح!');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
