-- Database schema for Driver Wallets and Transactions

-- 1. Create Driver Wallets table
CREATE TABLE IF NOT EXISTS public.driver_wallets (
    driver_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE PRIMARY KEY,
    balance NUMERIC NOT NULL DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::TEXT, now()) NOT NULL
);

-- 2. Create Transactions table
CREATE TABLE IF NOT EXISTS public.transactions (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
    driver_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
    trip_id uuid REFERENCES public.trips(id) ON DELETE SET NULL,
    booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
    taxi_request_id uuid REFERENCES public.taxi_requests(id) ON DELETE SET NULL,
    amount NUMERIC NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('deposit', 'withdrawal', 'fee', 'commission', 'trip_earning', 'trip_payment', 'penalty', 'refund')),
    provider TEXT NOT NULL, -- 'kiosk', 'amanah', 'system'
    provider_tx_id TEXT UNIQUE, -- Unique ID from the provider to prevent double processing
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'failed', 'cancelled')),
    metadata JSONB DEFAULT '{}'::JSONB, -- Store raw provider response or extra details
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::TEXT, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_driver_id ON public.transactions(driver_id);
CREATE INDEX IF NOT EXISTS idx_transactions_trip_id ON public.transactions(trip_id);
CREATE INDEX IF NOT EXISTS idx_transactions_booking_id ON public.transactions(booking_id);
CREATE INDEX IF NOT EXISTS idx_transactions_taxi_request_id ON public.transactions(taxi_request_id);

-- 3. Enable RLS
ALTER TABLE public.driver_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- 4. Policies
DROP POLICY IF EXISTS "Drivers can view their own wallet." ON public.driver_wallets;
CREATE POLICY "Drivers can view their own wallet." ON public.driver_wallets 
    FOR SELECT USING (auth.uid() = driver_id);

DROP POLICY IF EXISTS "Drivers can view their own transactions." ON public.transactions;
DROP POLICY IF EXISTS "Users can view their own transactions" ON public.transactions;
CREATE POLICY "Users can view their own transactions" ON public.transactions 
    FOR SELECT USING (auth.uid() = user_id OR auth.uid() = driver_id);

-- 5. Helper function to ensure wallet exists (lazy creation)
CREATE OR REPLACE FUNCTION public.ensure_driver_wallet(p_driver_id uuid)
RETURNS void AS $$
BEGIN
    INSERT INTO public.driver_wallets (driver_id, balance)
    VALUES (p_driver_id, 0)
    ON CONFLICT (driver_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Atomic function to process payment (used by Edge Function)
CREATE OR REPLACE FUNCTION public.process_payment_webhook(
    p_driver_id uuid,
    p_amount numeric,
    p_provider text,
    p_provider_tx_id text,
    p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb AS $$
DECLARE
    v_new_balance numeric;
BEGIN
    -- Ensure wallet exists
    PERFORM public.ensure_driver_wallet(p_driver_id);

    -- Check for duplicate transaction
    IF EXISTS (SELECT 1 FROM public.transactions WHERE provider_tx_id = p_provider_tx_id AND provider = p_provider) THEN
        SELECT balance INTO v_new_balance FROM public.driver_wallets WHERE driver_id = p_driver_id;
        RETURN jsonb_build_object('success', true, 'new_balance', v_new_balance, 'status', 'ALREADY_PROCESSED');
    END IF;

    -- Update wallet balance
    UPDATE public.driver_wallets
    SET balance = balance + p_amount,
        updated_at = now()
    WHERE driver_id = p_driver_id
    RETURNING balance INTO v_new_balance;

    -- Record transaction
    INSERT INTO public.transactions (driver_id, amount, type, provider, provider_tx_id, status, metadata)
    VALUES (p_driver_id, p_amount, 'deposit', p_provider, p_provider_tx_id, 'success', p_metadata);

    RETURN jsonb_build_object('success', true, 'new_balance', v_new_balance);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. تفعيل التحديث اللحظي للرصيد عبر Realtime
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND schemaname = 'public' 
    AND tablename = 'driver_wallets'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_wallets;
  END IF;
END $$;

