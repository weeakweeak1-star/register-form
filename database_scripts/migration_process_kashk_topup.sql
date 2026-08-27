-- Migration: Kashk Top-up RPC function
-- This function processes a successful top-up from Kashk securely.
-- It ensures atomicity (wallet balance update and transaction logging succeed or fail together)
-- and prevents duplicate top-ups using the Kashk transaction ID.

CREATE OR REPLACE FUNCTION public.process_kashk_topup(
  p_driver_id UUID,
  p_amount NUMERIC,
  p_kashk_transaction_id TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  -- 1. Check for duplicate transaction ID from Kashk to prevent double top-ups
  SELECT EXISTS(
    SELECT 1 FROM transactions
    WHERE provider_tx_id = p_kashk_transaction_id AND type = 'top_up' AND provider = 'kashk'
  ) INTO v_exists;

  IF v_exists THEN
    RAISE EXCEPTION 'Kashk Transaction % already processed', p_kashk_transaction_id;
  END IF;

  -- 2. Update driver wallet balance
  UPDATE driver_wallets
  SET 
    balance = balance + p_amount,
    updated_at = NOW()
  WHERE driver_id = p_driver_id;

  -- If the driver doesn't have a wallet yet, create one
  IF NOT FOUND THEN
    INSERT INTO driver_wallets (driver_id, balance, created_at, updated_at)
    VALUES (p_driver_id, p_amount, NOW(), NOW());
  END IF;

  -- 3. Insert the transaction record
  INSERT INTO transactions (
    user_id,
    driver_id,
    amount,
    type,
    status,
    provider,
    provider_tx_id,
    metadata
  ) VALUES (
    p_driver_id,
    p_driver_id,
    p_amount,
    'deposit', -- 'deposit' is the correct enum value for top_ups according to payment_schema
    'success',
    'kashk',
    p_kashk_transaction_id,
    jsonb_build_object('source', 'kashk_api', 'description', 'Kashk voucher redemption')
  );

  RETURN TRUE;
END;
$$;

-- Grant execution permission to authenticated users (so Edge Functions called by authenticated users can run it)
GRANT EXECUTE ON FUNCTION public.process_kashk_topup(UUID, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_kashk_topup(UUID, NUMERIC, TEXT) TO service_role;
