-- ==============================================================================
-- Migration: Enable RLS on driver_online_status table
-- ==============================================================================

-- 1. تفعيل جدار الحماية
ALTER TABLE public.driver_online_status ENABLE ROW LEVEL SECURITY;

-- 2. إزالة أي سياسات سابقة
DROP POLICY IF EXISTS "Drivers can manage their own status" ON public.driver_online_status;
DROP POLICY IF EXISTS "Authenticated users can read online drivers" ON public.driver_online_status;

-- 3. سياسة القراءة (SELECT)
-- يُسمح لأي مستخدم مسجل بمعرفة الكباتن المتصلين (لعرض الطلبات والإشعارات)
CREATE POLICY "Authenticated users can read online drivers"
ON public.driver_online_status
FOR SELECT
TO authenticated
USING (true);

-- 4. سياسة الإدراج والتعديل (INSERT + UPDATE)
-- الكابتن فقط يستطيع إضافة أو تحديث سجل الحالة الخاص به (لا يمكنه تعديل موقع كابتن آخر)
CREATE POLICY "Drivers can manage their own status"
ON public.driver_online_status
FOR ALL
TO authenticated
USING (driver_id = auth.uid())
WITH CHECK (driver_id = auth.uid());
