-- ==============================================================================
-- Migration: Add OTP Rate Limiting Table and Verification Function
-- ==============================================================================

-- 1. جدول تتبع محاولات طلب رمز التحقق (OTP)
CREATE TABLE IF NOT EXISTS public.otp_rate_limits (
    phone TEXT PRIMARY KEY,
    attempts_in_hour INT DEFAULT 1,
    first_attempt_in_hour TIMESTAMPTZ DEFAULT NOW(),
    last_attempt_at TIMESTAMPTZ DEFAULT NOW(),
    blocked_until TIMESTAMPTZ,
    daily_attempts INT DEFAULT 1,
    first_attempt_in_day TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- تفعيل RLS ومنع الوصول المباشر من المستخدمين لحماية السجل
ALTER TABLE public.otp_rate_limits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Deny direct user access to otp_rate_limits" ON public.otp_rate_limits;
CREATE POLICY "Deny direct user access to otp_rate_limits" ON public.otp_rate_limits
    FOR ALL USING (false);

-- 2. دالة التحقق وتسجيل محاولة طلب الرمز (Rate Limiting RPC)
CREATE OR REPLACE FUNCTION public.check_and_record_otp_attempt(p_phone TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_record RECORD;
  v_now TIMESTAMPTZ := NOW();
  v_cooldown_seconds INT := 60;      -- 60 ثانية بين كل طلب وآخر
  v_max_hourly_attempts INT := 5;     -- أقصى حد: 5 محاولات في الساعة
  v_max_daily_attempts INT := 10;     -- أقصى حد: 10 محاولات في اليوم
  v_seconds_since_last INT;
  v_clean_phone TEXT;
BEGIN
  v_clean_phone := TRIM(p_phone);
  
  IF v_clean_phone IS NULL OR LENGTH(v_clean_phone) < 8 THEN
    RETURN jsonb_build_object('allowed', false, 'error', 'INVALID_PHONE');
  END IF;

  SELECT * INTO v_record
  FROM public.otp_rate_limits
  WHERE phone = v_clean_phone
  FOR UPDATE;

  -- إذا كان الرقم يطلب لأول مرة
  IF NOT FOUND THEN
    INSERT INTO public.otp_rate_limits (phone, attempts_in_hour, first_attempt_in_hour, last_attempt_at, daily_attempts, first_attempt_in_day)
    VALUES (v_clean_phone, 1, v_now, v_now, 1, v_now);
    
    RETURN jsonb_build_object('allowed', true);
  END IF;

  -- أ. فحص الحظر المؤقت
  IF v_record.blocked_until IS NOT NULL AND v_record.blocked_until > v_now THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'error', 'BLOCKED',
      'retry_after_seconds', EXTRACT(EPOCH FROM (v_record.blocked_until - v_now))::INT
    );
  END IF;

  -- ب. فحص فترة التهدئة (60 ثانية)
  v_seconds_since_last := EXTRACT(EPOCH FROM (v_now - v_record.last_attempt_at))::INT;
  IF v_seconds_since_last < v_cooldown_seconds THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'error', 'COOLDOWN',
      'retry_after_seconds', (v_cooldown_seconds - v_seconds_since_last)
    );
  END IF;

  -- ج. تصفير عداد الساعة إذا مضت أكثر من 60 دقيقة
  IF v_now - v_record.first_attempt_in_hour > INTERVAL '1 hour' THEN
    v_record.attempts_in_hour := 0;
    v_record.first_attempt_in_hour := v_now;
  END IF;

  -- د. تصفير عداد اليوم إذا مضت أكثر من 24 ساعة
  IF v_now - v_record.first_attempt_in_day > INTERVAL '24 hours' THEN
    v_record.daily_attempts := 0;
    v_record.first_attempt_in_day := v_now;
  END IF;

  -- هـ. فحص الحد الأقصى الساعي (5 محاولات)
  IF v_record.attempts_in_hour >= v_max_hourly_attempts THEN
    UPDATE public.otp_rate_limits
    SET blocked_until = v_now + INTERVAL '1 hour',
        last_attempt_at = v_now
    WHERE phone = v_clean_phone;
    
    RETURN jsonb_build_object(
      'allowed', false,
      'error', 'HOURLY_LIMIT_EXCEEDED',
      'retry_after_seconds', 3600
    );
  END IF;

  -- و. فحص الحد الأقصى اليومي (10 محاولات)
  IF v_record.daily_attempts >= v_max_daily_attempts THEN
    UPDATE public.otp_rate_limits
    SET blocked_until = v_now + INTERVAL '12 hours',
        last_attempt_at = v_now
    WHERE phone = v_clean_phone;
    
    RETURN jsonb_build_object(
      'allowed', false,
      'error', 'DAILY_LIMIT_EXCEEDED',
      'retry_after_seconds', 43200
    );
  END IF;

  -- تحديث السجل والسماح بالطلب
  UPDATE public.otp_rate_limits
  SET attempts_in_hour = v_record.attempts_in_hour + 1,
      daily_attempts = v_record.daily_attempts + 1,
      last_attempt_at = v_now,
      first_attempt_in_hour = v_record.first_attempt_in_hour,
      first_attempt_in_day = v_record.first_attempt_in_day,
      blocked_until = NULL
  WHERE phone = v_clean_phone;

  RETURN jsonb_build_object('allowed', true);
END;
$$;
