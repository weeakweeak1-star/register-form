-- ==============================================================================
-- Migration: Fix driver_documents Storage Bucket & RLS Policies
-- ==============================================================================
-- هذا السكريبت يحل مشكلة الرفض (403 Unauthorized / new row violates row-level security policy)
-- عند قيام الكباتن غير المسجلين برفع صور المستمسكات عبر الاستمارة العامة

-- 1. التأكد من إنشاء الـ Bucket وأنه عام (public) وبحد أقصى مناسب للملفات (10MB)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'driver_documents',
  'driver_documents',
  true,
  10485760, -- 10 ميغابايت لكل صورة
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/heic', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/heic', 'image/gif'];

-- 2. إزالة أي سياسات سابقة متعارضة لتجنب التكرار
DROP POLICY IF EXISTS "Allow public uploads to driver_documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow anon insert to driver_documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow anon update to driver_documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read from driver_documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow anon select driver_documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated select driver_documents" ON storage.objects;

-- 3. سياسة السماح برفع الصور للمستخدمين غير المسجلين (anon) والمسجلين (authenticated)
CREATE POLICY "Allow anon insert to driver_documents"
ON storage.objects
FOR INSERT
TO public, anon, authenticated
WITH CHECK (bucket_id = 'driver_documents');

-- 4. سياسة السماح بتعديل أو إعادة رفع الصور عند الحاجة (UPDATE)
CREATE POLICY "Allow anon update to driver_documents"
ON storage.objects
FOR UPDATE
TO public, anon, authenticated
USING (bucket_id = 'driver_documents')
WITH CHECK (bucket_id = 'driver_documents');

-- 5. سياسة السماح بقراءة وعرض صور المستمسكات (SELECT)
CREATE POLICY "Allow anon select driver_documents"
ON storage.objects
FOR SELECT
TO public, anon, authenticated
USING (bucket_id = 'driver_documents');
