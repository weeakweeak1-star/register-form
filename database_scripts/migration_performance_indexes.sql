-- ==============================================================================
-- Migration: Performance Indexes for Peak Load Optimization
-- ==============================================================================
-- يُضيف الفهارس المفقودة على الجداول الحساسة لتسريع الاستعلامات في وقت الذروة.
-- استخدم CONCURRENTLY لتجنب قفل الجداول أثناء الإضافة.
-- ⚠️ ملاحظة: CREATE INDEX CONCURRENTLY لا يعمل داخل transaction block.
--    في Supabase SQL Editor، شغّل كل أمر CREATE INDEX CONCURRENTLY بشكل منفصل.
-- ==============================================================================

-- ┌──────────────────────────────────────────────────────────────┐
-- │  1. جدول trips — الجدول الأكثر استعلاماً                    │
-- └──────────────────────────────────────────────────────────────┘

-- فهرس على driver_id: يُسرّع جلب رحلات السائق (getDriverTrips)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_trips_driver_id
  ON public.trips(driver_id);

-- فهرس مركب على الحالة + المقاعد: يُسرّع بحث الرحلات المتاحة (searchTrips)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_trips_status_available
  ON public.trips(status, available_seats)
  WHERE status IN ('scheduled', 'started') AND available_seats > 0;

-- فهرس على departure_time: يُسرّع الترتيب والفلترة بالوقت
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_trips_departure_time
  ON public.trips(departure_time);

-- فهرس مركب على is_private + status: يُسرّع بحث الرحلات الخاصة
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_trips_private_status
  ON public.trips(is_private, status)
  WHERE is_private = true;

-- ┌──────────────────────────────────────────────────────────────┐
-- │  2. جدول bookings — حجوزات الركاب                          │
-- └──────────────────────────────────────────────────────────────┘

-- فهرس على trip_id: يُسرّع جلب حجوزات رحلة معينة (getTripBookings)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_bookings_trip_id
  ON public.bookings(trip_id);

-- فهرس على passenger_id: يُسرّع جلب حجوزات راكب معين
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_bookings_passenger_id
  ON public.bookings(passenger_id);

-- فهرس مركب passenger_id + status: يُسرّع فحص الحجوزات النشطة (التحقق قبل الحجز الجديد)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_bookings_passenger_status
  ON public.bookings(passenger_id, status);

-- فهرس مركب trip_id + status: يُسرّع RLS policy check_user_has_booking
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_bookings_trip_passenger
  ON public.bookings(trip_id, passenger_id);

-- ┌──────────────────────────────────────────────────────────────┐
-- │  3. جدول taxi_requests — طلبات التكسي                       │
-- └──────────────────────────────────────────────────────────────┘

-- فهرس على status: يُسرّع جلب الطلبات قيد البحث (streamIncomingRequests)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_taxi_requests_status
  ON public.taxi_requests(status);

-- فهرس جزئي على status = 'searching': يُسرّع accept_taxi_request بشكل كبير
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_taxi_requests_searching
  ON public.taxi_requests(id)
  WHERE status = 'searching' AND driver_id IS NULL;

-- فهرس مركب driver_id + status: يُسرّع جلب الطلبات النشطة للسائق
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_taxi_requests_driver_status
  ON public.taxi_requests(driver_id, status);

-- فهرس مركب passenger_id + status: يُسرّع فحص الطلبات النشطة قبل طلب جديد
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_taxi_requests_passenger_status
  ON public.taxi_requests(passenger_id, status);

-- فهرس على created_at: يُسرّع الترتيب في سجل الرحلات
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_taxi_requests_created_at
  ON public.taxi_requests(created_at DESC);

-- ┌──────────────────────────────────────────────────────────────┐
-- │  4. جدول driver_online_status — حالة السائقين المتصلين      │
-- └──────────────────────────────────────────────────────────────┘

-- فهرس جزئي على السائقين المتصلين: يُسرّع إرسال الإشعارات للكباتن المتاحين
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_driver_online_is_online
  ON public.driver_online_status(driver_id)
  WHERE is_online = true;

-- ┌──────────────────────────────────────────────────────────────┐
-- │  5. جدول profiles — ملفات المستخدمين                        │
-- └──────────────────────────────────────────────────────────────┘

-- فهرس جزئي على السائقين المعتمدين: يُسرّع RLS policies التي تتحقق من is_driver
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_profiles_active_drivers
  ON public.profiles(id)
  WHERE is_driver = true AND driver_status = 'approved';
