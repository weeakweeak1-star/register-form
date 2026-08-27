-- ============================================================
-- Migration: Add app_type to user_fcm_tokens
-- Purpose:   Distinguish captain tokens from customer tokens
--            so notifications are sent only to the correct app.
-- ============================================================

-- 1. Add app_type column (default 'customer' for existing rows)
ALTER TABLE public.user_fcm_tokens
  ADD COLUMN IF NOT EXISTS app_type TEXT NOT NULL DEFAULT 'customer'
  CHECK (app_type IN ('customer', 'captain'));

-- 2. Add index for faster filtering by app_type
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_app_type
  ON public.user_fcm_tokens(app_type);

-- 3. Drop old unique constraint on fcm_token (if any) and re-create
--    to allow same user to have one token per app_type per device
ALTER TABLE public.user_fcm_tokens
  DROP CONSTRAINT IF EXISTS user_fcm_tokens_fcm_token_key;

-- Re-create unique constraint: one token = one (user, app_type) pair
-- A single physical token cannot belong to two different apps anyway.
ALTER TABLE public.user_fcm_tokens
  ADD CONSTRAINT user_fcm_tokens_fcm_token_unique UNIQUE (fcm_token);

-- 4. Replace register_fcm_token function to accept app_type
CREATE OR REPLACE FUNCTION public.register_fcm_token(
  p_token     TEXT,
  p_device_type TEXT,
  p_app_type  TEXT DEFAULT 'customer'
)
RETURNS VOID AS $$
BEGIN
  -- Validate input
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_app_type NOT IN ('customer', 'captain') THEN
    RAISE EXCEPTION 'Invalid app_type: must be customer or captain';
  END IF;

  -- Upsert: if this exact token already exists update its owner & metadata
  INSERT INTO public.user_fcm_tokens (user_id, fcm_token, device_type, app_type, updated_at)
  VALUES (auth.uid(), p_token, p_device_type, p_app_type, timezone('utc'::TEXT, now()))
  ON CONFLICT (fcm_token) DO UPDATE
    SET user_id     = EXCLUDED.user_id,
        device_type = EXCLUDED.device_type,
        app_type    = EXCLUDED.app_type,
        updated_at  = EXCLUDED.updated_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
