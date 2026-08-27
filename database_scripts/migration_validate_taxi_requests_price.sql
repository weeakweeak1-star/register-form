-- ==============================================================================
-- Migration: Enforce NOT NULL and CHECK Constraints on taxi_requests.price
-- ==============================================================================

-- 1. معالجة أي طلبات قديمة تحتوي على سعر فارغ NULL أو صفر لتفادي فشل تطبيق القيد
UPDATE public.taxi_requests
SET price = 3000
WHERE price IS NULL OR price <= 0;

-- 2. إزالة القيود السابقة إن وجدت لضمان Idempotency
ALTER TABLE public.taxi_requests 
DROP CONSTRAINT IF EXISTS taxi_requests_price_check,
DROP CONSTRAINT IF EXISTS taxi_requests_status_check,
DROP CONSTRAINT IF EXISTS taxi_requests_coords_check;

-- 3. فرض قيد NOT NULL على عمود price
ALTER TABLE public.taxi_requests
ALTER COLUMN price SET NOT NULL;

-- 4. إضافة قيد التحقق من أن السعر دائماً رقم موجب أكبر من الصفر
ALTER TABLE public.taxi_requests
ADD CONSTRAINT taxi_requests_price_check CHECK (price > 0);

-- 5. إضافة قيد التحقق من حالات الطلب المعتمدة
ALTER TABLE public.taxi_requests
ADD CONSTRAINT taxi_requests_status_check 
CHECK (status IN ('searching', 'accepted', 'arrived', 'ongoing', 'completed', 'cancelled'));

-- 6. إضافة قيد التحقق من صحة الإحداثيات الجغرافية
ALTER TABLE public.taxi_requests
ADD CONSTRAINT taxi_requests_coords_check 
CHECK (
  pickup_lat BETWEEN -90 AND 90 AND 
  pickup_lng BETWEEN -180 AND 180 AND 
  dropoff_lat BETWEEN -90 AND 90 AND 
  dropoff_lng BETWEEN -180 AND 180
);
