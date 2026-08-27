-- 1. إضافة العمود الجديد إلى جدول الحسابات
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS has_ridden_as_customer BOOLEAN DEFAULT false;

-- 2. تحديث الحسابات القديمة (التي قامت بطلب رحلة سابقاً)
UPDATE public.profiles p
SET has_ridden_as_customer = true
WHERE EXISTS (
    SELECT 1 FROM public.taxi_requests t WHERE t.passenger_id = p.id
) OR EXISTS (
    SELECT 1 FROM public.bookings b WHERE b.passenger_id = p.id
);

-- 3. إنشاء دالة تعمل تلقائياً عند طلب أي رحلة جديدة
CREATE OR REPLACE FUNCTION public.mark_as_customer_on_request()
RETURNS TRIGGER AS $$
BEGIN
    -- تغيير قيمة العمود إلى true لصاحب الطلب
    UPDATE public.profiles
    SET has_ridden_as_customer = true
    WHERE id = NEW.passenger_id AND has_ridden_as_customer = false;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. ربط الدالة بجدول طلبات التاكسي الفوري
DROP TRIGGER IF EXISTS trigger_mark_as_customer_taxi ON public.taxi_requests;
CREATE TRIGGER trigger_mark_as_customer_taxi
AFTER INSERT ON public.taxi_requests
FOR EACH ROW
EXECUTE FUNCTION public.mark_as_customer_on_request();

-- 5. ربط الدالة بجدول حجوزات الرحلات المشتركة
DROP TRIGGER IF EXISTS trigger_mark_as_customer_bookings ON public.bookings;
CREATE TRIGGER trigger_mark_as_customer_bookings
AFTER INSERT ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.mark_as_customer_on_request();
