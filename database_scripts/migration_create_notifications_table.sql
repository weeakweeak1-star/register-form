-- 1. Create the notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    target_driver_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE, -- Can be null for 'all'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 3. Add RLS policies (Admins can insert)
CREATE POLICY "Enable insert for authenticated users" 
ON public.notifications
FOR INSERT 
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Enable select for authenticated users" 
ON public.notifications
FOR SELECT 
USING (auth.role() = 'authenticated');

-- 4. Add the webhook trigger so it sends the push notification automatically via Edge Function
DROP TRIGGER IF EXISTS tr_admin_notifications ON public.notifications;
CREATE TRIGGER tr_admin_notifications
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION supabase_functions.http_request(
    'https://lvyqpyqkutdycdldoebw.supabase.co/functions/v1/send-notification',
    'POST',
    '{"Content-Type":"application/json"}'
  );
