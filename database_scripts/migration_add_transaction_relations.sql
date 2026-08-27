-- ==============================================================================
-- Migration: Add Relations (trip_id, booking_id, taxi_request_id, user_id) to transactions
-- ==============================================================================

-- 1. إضافة أعمدة الربط بالرحلات والحجوزات والمستخدمين
ALTER TABLE public.transactions
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS trip_id UUID REFERENCES public.trips(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS taxi_request_id UUID REFERENCES public.taxi_requests(id) ON DELETE SET NULL;

-- 2. تعبئة user_id تلقائياً للبيانات السابقة من عمود driver_id
UPDATE public.transactions
SET user_id = driver_id
WHERE user_id IS NULL AND driver_id IS NOT NULL;

-- 3. إنشاء فهارس (Indexes) لتسريع البحث المالي واسترجاع كشف الحساب والتقارير
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_trip_id ON public.transactions(trip_id);
CREATE INDEX IF NOT EXISTS idx_transactions_booking_id ON public.transactions(booking_id);
CREATE INDEX IF NOT EXISTS idx_transactions_taxi_request_id ON public.transactions(taxi_request_id);

-- 4. إضافة قيود التحقق (CHECK Constraints) لصحة العمليات والحالات
ALTER TABLE public.transactions
DROP CONSTRAINT IF EXISTS transactions_status_check,
DROP CONSTRAINT IF EXISTS transactions_type_check;

ALTER TABLE public.transactions
ADD CONSTRAINT transactions_status_check 
CHECK (status IN ('pending', 'success', 'failed', 'cancelled'));

ALTER TABLE public.transactions
ADD CONSTRAINT transactions_type_check 
CHECK (type IN ('deposit', 'withdrawal', 'fee', 'commission', 'trip_earning', 'trip_payment', 'penalty', 'refund'));

-- 5. تحديث سياسة RLS لتمكين المستخدمين (سائق أو راكب) من رؤية معاملاتهم
DROP POLICY IF EXISTS "Drivers can view their own transactions." ON public.transactions;
DROP POLICY IF EXISTS "Users can view their own transactions" ON public.transactions;

CREATE POLICY "Users can view their own transactions" ON public.transactions 
    FOR SELECT 
    TO authenticated
    USING (auth.uid() = user_id OR auth.uid() = driver_id);
