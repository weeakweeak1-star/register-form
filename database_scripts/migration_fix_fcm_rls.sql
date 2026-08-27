-- 1. Create a secure RPC to register/update FCM tokens
-- This avoids RLS issues when a device's token changes ownership (e.g. new user logs into the same device)
CREATE OR REPLACE FUNCTION public.register_fcm_token(p_token TEXT, p_device_type TEXT)
RETURNS VOID AS $$
BEGIN
    -- Ensure the user is authenticated
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Upsert the token safely
    INSERT INTO public.user_fcm_tokens (user_id, fcm_token, device_type, updated_at)
    VALUES (auth.uid(), p_token, p_device_type, timezone('utc'::TEXT, now()))
    ON CONFLICT (fcm_token) DO UPDATE
    SET user_id = EXCLUDED.user_id,
        device_type = EXCLUDED.device_type,
        updated_at = EXCLUDED.updated_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
