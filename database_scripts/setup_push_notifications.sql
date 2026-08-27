-- 1. تفعيل إضافة pg_net المسؤولة عن الـ Webhooks والاستدعاءات البرمجية
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. إنشاء schema والدالة supabase_functions.http_request التابعة لـ Supabase Webhooks
CREATE SCHEMA IF NOT EXISTS supabase_functions;

CREATE OR REPLACE FUNCTION supabase_functions.http_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  request_id bigint;
  payload jsonb;
  url text := TG_ARGV[0];
  method text := TG_ARGV[1];
  headers jsonb := coalesce(TG_ARGV[2]::jsonb, '{}'::jsonb);
  params jsonb := coalesce(TG_ARGV[3]::jsonb, '{}'::jsonb);
  timeout_ms integer := coalesce(TG_ARGV[4]::integer, 5000);
BEGIN
  payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE row_to_json(NEW)::jsonb END,
    'old_record', CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE row_to_json(OLD)::jsonb END
  );

  SELECT net.http_post(
    url := url,
    headers := headers,
    body := payload,
    timeout_milliseconds := timeout_ms
  ) INTO request_id;

  RETURN NEW;
END;
$$;

-- 3. إضافة التريجر المباشر لجدول taxi_requests (اختياري - يعمل تلقائياً مع الـ Webhooks)
DROP TRIGGER IF EXISTS tr_taxi_requests_notification ON taxi_requests;
CREATE TRIGGER tr_taxi_requests_notification
  AFTER UPDATE ON taxi_requests
  FOR EACH ROW
  EXECUTE FUNCTION supabase_functions.http_request(
    'https://lvyqpyqkutdycdldoebw.supabase.co/functions/v1/send-notification',
    'POST',
    '{"Content-Type":"application/json"}'
  );

-- 4. إضافة التريجر المباشر لجدول bookings
DROP TRIGGER IF EXISTS tr_bookings_notification ON bookings;
CREATE TRIGGER tr_bookings_notification
  AFTER INSERT OR UPDATE ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION supabase_functions.http_request(
    'https://lvyqpyqkutdycdldoebw.supabase.co/functions/v1/send-notification',
    'POST',
    '{"Content-Type":"application/json"}'
  );
