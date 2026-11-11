-- 002: indexes
--
-- Target query:
--   SELECT org_id, status, COUNT(*), SUM(amount)
--   FROM hotel_bookings
--   WHERE city = 'delhi' AND created_at >= NOW() - INTERVAL '30 days'
--   GROUP BY org_id, status;
--
-- Equality column first (city), range column second (created_at), then the
-- remaining columns the query reads as INCLUDE payload so Postgres can answer
-- it with an Index Only Scan and never touch the heap.
CREATE INDEX idx_hotel_bookings_city_created_at_cov
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);

-- Supports "all events for a booking" lookups and FK cascade deletes.
CREATE INDEX idx_booking_events_booking_id
    ON booking_events (booking_id, created_at);
