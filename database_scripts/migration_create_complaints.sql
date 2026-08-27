-- إنشاء جدول البلاغات والشكاوى
CREATE TABLE IF NOT EXISTS public.complaints (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    trip_id UUID REFERENCES public.trips(id) ON DELETE SET NULL,
    message TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processed', 'dismissed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- تفعيل سياسات الأمان
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;

-- السماح للمستخدمين بإضافة الشكاوى
CREATE POLICY "Users can insert their own complaints"
ON public.complaints FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- السماح للمستخدمين برؤية شكاواهم فقط
CREATE POLICY "Users can view their own complaints"
ON public.complaints FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- السماح للأدمن برؤية وتحديث الشكاوى (مؤقتاً لأن لوحة التحكم تستخدم anon_key)
CREATE POLICY "Allow public read to complaints" ON public.complaints FOR SELECT USING (true);
CREATE POLICY "Allow public update to complaints" ON public.complaints FOR UPDATE USING (true);
