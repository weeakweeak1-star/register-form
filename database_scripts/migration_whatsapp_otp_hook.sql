-- ==============================================================================
-- Migration: WhatsApp OTP Authentication Flow & Rate Limiting Integration
-- ==============================================================================

-- 1. التأكد من وجود جدول تتبع محاولات OTP (Rate Limiting)
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

ALTER TABLE public.otp_rate_limits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Deny direct user access to otp_rate_limits" ON public.otp_rate_limits;
CREATE POLICY "Deny direct user access to otp_rate_limits" ON public.otp_rate_limits
    FOR ALL USING (false);

-- 2. إرشادات تفعيل مسار WhatsApp في Supabase Dashboard:
-- -----------------------------------------------------------------------------
-- خيار أ (Supabase Auth Hook - Send SMS/WhatsApp Hook):
-- 1. توجه إلى: Authentication -> Hooks -> Send SMS Hook
-- 2. اختر نوع الـ Hook: HTTP / Supabase Edge Function
-- 3. حدد مسار الـ Function: send-whatsapp-otp
-- 4. أضف متغيرات البيئة في Supabase Secrets:
--    supabase secrets set WHATSAPP_API_KEY="your_meta_token" WHATSAPP_PHONE_NUMBER_ID="your_phone_id"
-- 
-- خيار ب (Twilio WhatsApp Provider المدمج في Supabase):
-- 1. توجه إلى: Authentication -> Providers -> Phone
-- 2. تفعيل خيار: Enable Phone Provider
-- 3. تحديد SMS Provider: Twilio
-- 4. تفعيل WhatsApp Support (أو إدخال رقم هاتف Twilio بصيغة whatsapp:+14155238886)
-- ==============================================================================
