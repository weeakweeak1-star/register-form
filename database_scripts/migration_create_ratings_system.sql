-- ==============================================================================
-- Migration: Create ratings table & Auto-update profile average rating Trigger
-- ==============================================================================

-- 1. التأكد من وجود عمود rating في جدول profiles
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS rating DOUBLE PRECISION DEFAULT 5.0;

-- 2. إنشاء جدول التقييمات الشامل (يدعم رحلات المحافظات وطلبات التكسي)
CREATE TABLE IF NOT EXISTS public.ratings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    rater_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    ratee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    trip_id UUID REFERENCES public.trips(id) ON DELETE SET NULL,
    booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
    taxi_request_id UUID REFERENCES public.taxi_requests(id) ON DELETE SET NULL,
    score INT NOT NULL CHECK (score >= 1 AND score <= 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::TEXT, now()) NOT NULL,
    
    -- قيد يمنع المستخدم من تقييم نفسه
    CONSTRAINT ratings_no_self_rating CHECK (rater_id <> ratee_id)
);

-- 3. منع تكرار التقييم لنفس الرحلة أو الحجز من قِبل نفس المقيم
CREATE UNIQUE INDEX IF NOT EXISTS uq_ratings_booking_rater 
ON public.ratings(booking_id, rater_id) 
WHERE booking_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_ratings_taxi_rater 
ON public.ratings(taxi_request_id, rater_id) 
WHERE taxi_request_id IS NOT NULL;

-- 4. فهارس سريعة للاستعلامات
CREATE INDEX IF NOT EXISTS idx_ratings_ratee_id ON public.ratings(ratee_id);
CREATE INDEX IF NOT EXISTS idx_ratings_rater_id ON public.ratings(rater_id);
CREATE INDEX IF NOT EXISTS idx_ratings_trip_id ON public.ratings(trip_id);

-- 5. تفعيل حماية RLS
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;

-- 6. سياسات RLS:
-- الجميع يمكنهم قراءة التقييمات
DROP POLICY IF EXISTS "Ratings are viewable by authenticated users" ON public.ratings;
CREATE POLICY "Ratings are viewable by authenticated users" ON public.ratings
    FOR SELECT
    TO authenticated
    USING (true);

-- المستخدم المسجل يمكنه فقط إضافة تقييم باسمه
DROP POLICY IF EXISTS "Users can insert their own ratings" ON public.ratings;
CREATE POLICY "Users can insert their own ratings" ON public.ratings
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = rater_id AND rater_id <> ratee_id);

-- 7. دالة وتريجر لتحديث معدل التقييم (rating) في جدول profiles تلقائياً
CREATE OR REPLACE FUNCTION public.update_profile_rating()
RETURNS TRIGGER AS $$
DECLARE
  v_target_user_id UUID;
  v_avg_rating DOUBLE PRECISION;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_target_user_id := OLD.ratee_id;
  ELSE
    v_target_user_id := NEW.ratee_id;
  END IF;

  -- حساب المتوسط الحسابي للتقييمات، وإذا لم تكن هناك تقييمات سابقة نعتمد 5.0
  SELECT COALESCE(ROUND(AVG(score)::numeric, 2), 5.0)
  INTO v_avg_rating
  FROM public.ratings
  WHERE ratee_id = v_target_user_id;

  -- تحديث التقييم التراكمي في الملف الشخصي للمستخدم
  UPDATE public.profiles
  SET rating = v_avg_rating
  WHERE id = v_target_user_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_update_profile_rating ON public.ratings;
CREATE TRIGGER tr_update_profile_rating
AFTER INSERT OR UPDATE OR DELETE ON public.ratings
FOR EACH ROW EXECUTE FUNCTION public.update_profile_rating();
