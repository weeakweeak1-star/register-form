-- Drop the old table since we changed the schema
DROP TABLE IF EXISTS public.driver_applications;

-- Create driver_applications table with new documents schema
CREATE TABLE public.driver_applications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    phone_number TEXT NOT NULL,
    full_name TEXT NOT NULL,
    profile_picture_url TEXT NOT NULL,
    id_card_front_url TEXT NOT NULL,
    id_card_back_url TEXT NOT NULL,
    car_reg_front_url TEXT NOT NULL,
    car_reg_back_url TEXT NOT NULL,
    license_url TEXT NOT NULL,
    power_of_attorney_url TEXT,
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
