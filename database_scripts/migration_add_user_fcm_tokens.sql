-- ==============================================================================
-- Migration: Create user_fcm_tokens table for multi-device push notifications
-- ==============================================================================

-- 1. إنشاء جدول مخصص لحفظ توكنات أجهزة المستخدمين (يدعم تعدد الأجهزة)
CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL UNIQUE,
    device_type TEXT DEFAULT 'android', -- 'android', 'ios', 'web'
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::TEXT, now()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::TEXT, now()) NOT NULL
);

-- 2. إنشاء فهارس (Indexes) لتسريع الاستعلامات وعمليات الإرسال
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user_id ON public.user_fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_token ON public.user_fcm_tokens(fcm_token);

-- 3. تفعيل حماية Row Level Security (RLS)
ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- 4. سياسات الأمان (RLS Policies):
-- المستخدم يمكنه فقط قراءة وتعديل وحذف التوكنات التابعة له فقط
DROP POLICY IF EXISTS "Users can manage own tokens" ON public.user_fcm_tokens;
CREATE POLICY "Users can manage own tokens" ON public.user_fcm_tokens
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 5. تريجر تلقائي لتحديث وقت آخر نشاط للتوكن (updated_at)
CREATE OR REPLACE FUNCTION update_user_fcm_tokens_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::TEXT, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_user_fcm_tokens_updated_at ON public.user_fcm_tokens;
CREATE TRIGGER tr_user_fcm_tokens_updated_at
BEFORE UPDATE ON public.user_fcm_tokens
FOR EACH ROW EXECUTE FUNCTION update_user_fcm_tokens_updated_at();
