-- Create driver_online_status table
CREATE TABLE public.driver_online_status (
    driver_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    current_lat DOUBLE PRECISION,
    current_lng DOUBLE PRECISION,
    is_online BOOLEAN DEFAULT false,
    last_updated TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS for driver_online_status
ALTER TABLE public.driver_online_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "driver_online_status is viewable by everyone" ON public.driver_online_status
    FOR SELECT USING (true);

CREATE POLICY "drivers can update their own status" ON public.driver_online_status
    FOR ALL USING (auth.uid() = driver_id);

-- Create taxi_requests table
CREATE TABLE public.taxi_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    passenger_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    pickup_lat DOUBLE PRECISION NOT NULL,
    pickup_lng DOUBLE PRECISION NOT NULL,
    dropoff_lat DOUBLE PRECISION NOT NULL,
    dropoff_lng DOUBLE PRECISION NOT NULL,
    price DOUBLE PRECISION NOT NULL CHECK (price > 0),
    status TEXT NOT NULL DEFAULT 'searching' CHECK (status IN ('searching', 'accepted', 'arrived', 'ongoing', 'completed', 'cancelled')),
    driver_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT taxi_requests_coords_check CHECK (
        pickup_lat BETWEEN -90 AND 90 AND 
        pickup_lng BETWEEN -180 AND 180 AND 
        dropoff_lat BETWEEN -90 AND 90 AND 
        dropoff_lng BETWEEN -180 AND 180
    )
);

-- Enable RLS for taxi_requests
ALTER TABLE public.taxi_requests ENABLE ROW LEVEL SECURITY;

-- Policies for taxi_requests
CREATE POLICY "taxi_requests is viewable by everyone" ON public.taxi_requests
    FOR SELECT USING (true);

CREATE POLICY "passengers can insert their own requests" ON public.taxi_requests
    FOR INSERT WITH CHECK (auth.uid() = passenger_id);

CREATE POLICY "passengers can update own requests" ON public.taxi_requests
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = passenger_id)
    WITH CHECK (auth.uid() = passenger_id);

CREATE POLICY "assigned drivers can update requests" ON public.taxi_requests
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = driver_id)
    WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "drivers can accept searching requests" ON public.taxi_requests
    FOR UPDATE
    TO authenticated
    USING (
        status = 'searching' 
        AND driver_id IS NULL
        AND auth.uid() <> passenger_id
        AND EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND is_driver = true
        )
    )
    WITH CHECK (
        driver_id = auth.uid()
        AND status = 'accepted'
    );

-- Add updated_at trigger for taxi_requests
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_taxi_requests_modtime
BEFORE UPDATE ON public.taxi_requests
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- Add tables to realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.taxi_requests;
ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_online_status;
