-- ==============================================================================
-- Security Migration: Enable Row Level Security (RLS) on taxi_requests table
-- ==============================================================================

-- 1. تفعيل جدار الحماية (RLS) على جدول طلبات التكسي
ALTER TABLE public.taxi_requests ENABLE ROW LEVEL SECURITY;

-- 2. إزالة أي سياسات سابقة إن وجدت لتجنب التعارض
DROP POLICY IF EXISTS "Allow select for passenger or driver or searching" ON public.taxi_requests;
DROP POLICY IF EXISTS "Allow insert for passenger" ON public.taxi_requests;
DROP POLICY IF EXISTS "Allow update for passenger or driver" ON public.taxi_requests;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.taxi_requests;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.taxi_requests;
DROP POLICY IF EXISTS "Enable update for users based on passenger_id or driver_id" ON public.taxi_requests;

-- 3. سياسة القراءة (SELECT)
-- يُسمح للزبون برؤية رحلاته الخاصة فقط
-- يُسمح للكابتن برؤية الرحلات التي تبحث عن سائق (searching) أو الرحلات المخصصة له
CREATE POLICY "Allow select for passenger or driver or searching"
ON public.taxi_requests
FOR SELECT
USING (
  passenger_id = auth.uid() 
  OR driver_id = auth.uid() 
  OR status = 'searching'
);

-- 4. سياسة الإضافة (INSERT)
-- يُسمح بإضافة رحلة جديدة فقط إذا كان الزبون يطلبها لنفسه (مطابقة الـ ID)
CREATE POLICY "Allow insert for passenger"
ON public.taxi_requests
FOR INSERT
WITH CHECK (
  passenger_id = auth.uid()
);

-- 5. سياسة التعديل (UPDATE)
-- يُسمح بتعديل الرحلة فقط لـ:
-- أ) الزبون صاحب الرحلة (مثلاً لإلغائها)
-- ب) الكابتن المخصص للرحلة (لتحديث حالتها إلى ongoing أو completed)
-- ج) أي كابتن إذا كانت الرحلة searching (لكي يقبلها ويخصصها لنفسه)
CREATE POLICY "Allow update for passenger or driver"
ON public.taxi_requests
FOR UPDATE
USING (
  passenger_id = auth.uid() 
  OR driver_id = auth.uid() 
  OR status = 'searching'
)
WITH CHECK (
  passenger_id = auth.uid() 
  OR driver_id = auth.uid() 
  OR status = 'searching'
);

-- سياسة الحذف (DELETE) - اختياري، يُفضل منعه أو حصره للزبون لو أراد مسح السجل
DROP POLICY IF EXISTS "Allow delete for passenger" ON public.taxi_requests;
CREATE POLICY "Allow delete for passenger"
ON public.taxi_requests
FOR DELETE
USING (
  passenger_id = auth.uid()
);
