-- إضافة عمود سبب الرفض لجدول طلبات التسجيل
ALTER TABLE public.driver_applications 
ADD COLUMN IF NOT EXISTS reject_reason TEXT;

-- إضافة عمود سبب الرفض/الحظر لجدول الملفات الشخصية (الكباتن)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS reject_reason TEXT;
