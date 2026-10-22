-- ==============================================================================
-- صلاحيات إدارة محافظ وسجلات الكباتن للمدير (Admin Access for driver_wallets & transactions)
-- ==============================================================================

-- 1. التأكد من تمكين RLS
ALTER TABLE public.driver_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- 2. سياسة قراءة وإدارة محافظ الكباتن للمدير (driver_wallets)
DROP POLICY IF EXISTS "Admins can manage all driver wallets" ON public.driver_wallets;
CREATE POLICY "Admins can manage all driver wallets" ON public.driver_wallets
    FOR ALL TO authenticated
    USING ( (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true )
    WITH CHECK ( (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true );

-- 3. سياسة قراءة وإدارة جميع العمليات المالية للمدير (transactions)
DROP POLICY IF EXISTS "Admins can manage all transactions" ON public.transactions;
CREATE POLICY "Admins can manage all transactions" ON public.transactions
    FOR ALL TO authenticated
    USING ( (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true )
    WITH CHECK ( (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true );
