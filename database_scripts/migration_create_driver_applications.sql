-- Create driver_applications table
CREATE TABLE IF NOT EXISTS public.driver_applications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    phone_number TEXT NOT NULL,
    full_name TEXT NOT NULL,
    car_type TEXT NOT NULL,
    car_model TEXT NOT NULL,
    car_color TEXT NOT NULL,
    car_plate TEXT NOT NULL,
    id_card_url TEXT NOT NULL,
    license_url TEXT NOT NULL,
    car_registration_url TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.driver_applications ENABLE ROW LEVEL SECURITY;

-- Allow anyone to insert an application (public form)
CREATE POLICY "Allow public insert to driver_applications"
ON public.driver_applications
FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- Allow admins (or authenticated users for now) to view and update
CREATE POLICY "Allow authenticated select to driver_applications"
ON public.driver_applications
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Allow authenticated update to driver_applications"
ON public.driver_applications
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Create Storage Bucket for documents
INSERT INTO storage.buckets (id, name, public) 
VALUES ('driver_documents', 'driver_documents', true)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS Policies
-- Allow anyone to upload documents
CREATE POLICY "Allow public uploads to driver_documents"
ON storage.objects
FOR INSERT
TO anon, authenticated
WITH CHECK (bucket_id = 'driver_documents');

-- Allow public to view their uploaded files (needed to show image preview maybe)
-- Or just restrict it to authenticated users for privacy
CREATE POLICY "Allow public read from driver_documents"
ON storage.objects
FOR SELECT
TO anon, authenticated
USING (bucket_id = 'driver_documents');
