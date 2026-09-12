-- ==============================================================================
-- Migration: Promotions Logic (Triggers and RPCs)
-- Description: Handles automatic promo assignment, fare calculation, locking, and driver compensation
-- ==============================================================================

-- 1. Trigger to give welcome coupon on new profile registration
CREATE OR REPLACE FUNCTION public.assign_welcome_promo()
RETURNS TRIGGER AS $$
DECLARE
    v_promo_id uuid;
BEGIN
    -- Find the active welcome promo
    SELECT id INTO v_promo_id FROM public.promotions WHERE is_welcome_offer = true AND is_active = true LIMIT 1;
    
    IF FOUND THEN
        INSERT INTO public.user_coupons (user_id, promo_id, status)
        VALUES (NEW.id, v_promo_id, 'AVAILABLE')
        ON CONFLICT DO NOTHING;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_assign_welcome_promo ON public.profiles;
CREATE TRIGGER tr_assign_welcome_promo
AFTER INSERT ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.assign_welcome_promo();


-- 2. RPC to get the best applicable promo and calculate the new price
CREATE OR REPLACE FUNCTION public.calculate_discounted_fare(
    p_passenger_id uuid,
    p_original_price numeric,
    p_trip_type text
)
RETURNS jsonb AS $$
DECLARE
    v_promo RECORD;
    v_discount_amount numeric := 0;
    v_final_price numeric;
BEGIN
    -- Find the best available promo for this user and trip type
    SELECT p.id, p.discount_type, p.discount_value, p.max_discount
    INTO v_promo
    FROM public.user_coupons uc
    JOIN public.promotions p ON uc.promo_id = p.id
    WHERE uc.user_id = p_passenger_id 
      AND uc.status = 'AVAILABLE' 
      AND p.is_active = true
      AND (p.expires_at IS NULL OR p.expires_at > now())
      AND (p.max_total_uses IS NULL OR p.current_uses < p.max_total_uses)
      AND (p_original_price >= COALESCE(p.min_fare, 0))
      AND (p.target_trip_type IS NULL OR p.target_trip_type = p_trip_type)
    ORDER BY p.created_at DESC
    LIMIT 1;

    IF FOUND THEN
        IF v_promo.discount_type = 'PERCENTAGE' THEN
            v_discount_amount := p_original_price * (v_promo.discount_value / 100.0);
        ELSE
            v_discount_amount := v_promo.discount_value;
        END IF;

        IF v_promo.max_discount IS NOT NULL AND v_discount_amount > v_promo.max_discount THEN
            v_discount_amount := v_promo.max_discount;
        END IF;

        IF v_discount_amount > p_original_price THEN
            v_discount_amount := p_original_price;
        END IF;
        
        v_final_price := p_original_price - v_discount_amount;
        
        RETURN jsonb_build_object(
            'has_promo', true,
            'promo_id', v_promo.id,
            'original_price', p_original_price,
            'discount_amount', v_discount_amount,
            'final_price', v_final_price
        );
    ELSE
        RETURN jsonb_build_object(
            'has_promo', false,
            'original_price', p_original_price,
            'discount_amount', 0,
            'final_price', p_original_price
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. Trigger to LOCK the coupon when a taxi_request is created
CREATE OR REPLACE FUNCTION public.lock_promo_on_request()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.promo_id IS NOT NULL THEN
        UPDATE public.user_coupons
        SET status = 'LOCKED'
        WHERE user_id = NEW.passenger_id AND promo_id = NEW.promo_id AND status = 'AVAILABLE';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_lock_promo_on_request ON public.taxi_requests;
CREATE TRIGGER tr_lock_promo_on_request
BEFORE INSERT ON public.taxi_requests
FOR EACH ROW
EXECUTE FUNCTION public.lock_promo_on_request();


-- 4. Trigger to handle cancellation or completion (Unlock/Use Promo and Compensate Driver)
CREATE OR REPLACE FUNCTION public.handle_promo_on_trip_update()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.promo_id IS NOT NULL THEN
        -- If cancelled, revert to AVAILABLE
        IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
            UPDATE public.user_coupons
            SET status = 'AVAILABLE'
            WHERE user_id = NEW.passenger_id AND promo_id = NEW.promo_id AND status = 'LOCKED';
        END IF;

        -- If completed, mark as USED and compensate driver
        IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
            UPDATE public.user_coupons
            SET status = 'USED', used_at = now()
            WHERE user_id = NEW.passenger_id AND promo_id = NEW.promo_id AND status = 'LOCKED';

            -- Increment current_uses for the promotion
            UPDATE public.promotions
            SET current_uses = current_uses + 1
            WHERE id = NEW.promo_id;

            -- Compensate Driver for the discount amount
            IF NEW.discount_amount > 0 THEN
                -- Ensure wallet exists
                INSERT INTO public.driver_wallets (driver_id, balance)
                VALUES (NEW.driver_id, 0)
                ON CONFLICT (driver_id) DO NOTHING;
                
                -- Add to wallet
                UPDATE public.driver_wallets
                SET balance = balance + NEW.discount_amount,
                    updated_at = NOW()
                WHERE driver_id = NEW.driver_id;
                
                -- Record compensation transaction
                INSERT INTO public.transactions (user_id, driver_id, amount, type, provider, status, taxi_request_id)
                VALUES (NEW.driver_id, NEW.driver_id, NEW.discount_amount, 'promo_compensation', 'system', 'success', NEW.id);
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_handle_promo_on_trip_update ON public.taxi_requests;
CREATE TRIGGER tr_handle_promo_on_trip_update
AFTER UPDATE ON public.taxi_requests
FOR EACH ROW
EXECUTE FUNCTION public.handle_promo_on_trip_update();
