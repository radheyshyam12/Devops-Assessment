-- 003: seed data (2,000 bookings, 5 orgs, 6 cities, 4 statuses, ~3,000 events)
BEGIN;

SELECT setseed(0.42);

WITH params AS (
    SELECT
        ARRAY[
            '11111111-1111-1111-1111-111111111111',
            '22222222-2222-2222-2222-222222222222',
            '33333333-3333-3333-3333-333333333333',
            '44444444-4444-4444-4444-444444444444',
            '55555555-5555-5555-5555-555555555555'
        ]::uuid[]                                                              AS orgs,
        ARRAY['delhi','mumbai','bengaluru','hyderabad','chennai','pune']        AS cities,
        ARRAY['confirmed','pending','cancelled','completed']                    AS statuses
),
base AS (
    SELECT
        p.orgs[1 + floor(random() * array_length(p.orgs, 1))::int]         AS org_id,
        'HTL-' || lpad((1 + floor(random() * 40))::int::text, 3, '0')      AS hotel_id,
        p.cities[1 + floor(random() * array_length(p.cities, 1))::int]     AS city,
        p.statuses[1 + floor(random() * array_length(p.statuses, 1))::int] AS status,
        round((2000 + random() * 48000)::numeric, 2)                       AS amount,
        (NOW() - random() * INTERVAL '90 days')::timestamp                 AS created_at,
        (1 + floor(random() * 60))::int                                    AS lead_days,
        (1 + floor(random() * 7))::int                                     AS nights
    FROM params p, generate_series(1, 2000) AS gs
)
INSERT INTO hotel_bookings
    (id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at)
SELECT
    gen_random_uuid(), org_id, hotel_id, city,
    created_at::date + lead_days,
    created_at::date + lead_days + nights,
    amount, status, created_at
FROM base;

-- Every booking gets a creation event.
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT id, 'booking_created',
       jsonb_build_object('source', (ARRAY['web','mobile','api'])[1 + floor(random() * 3)::int],
                          'amount', amount),
       created_at
FROM hotel_bookings;

-- Confirmed / completed bookings get a confirmation event.
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT id, 'booking_confirmed',
       jsonb_build_object('payment_method', (ARRAY['card','upi','netbanking'])[1 + floor(random() * 3)::int]),
       created_at + INTERVAL '5 minutes'
FROM hotel_bookings
WHERE status IN ('confirmed', 'completed');

-- Cancelled bookings get a cancellation event.
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT id, 'booking_cancelled',
       jsonb_build_object('reason', (ARRAY['customer_request','payment_failed','hotel_unavailable'])[1 + floor(random() * 3)::int]),
       created_at + INTERVAL '30 minutes'
FROM hotel_bookings
WHERE status = 'cancelled';

-- Completed bookings get a stay-completed event.
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT id, 'stay_completed', '{}'::jsonb, created_at + INTERVAL '1 hour'
FROM hotel_bookings
WHERE status = 'completed';

COMMIT;

-- Fresh stats + visibility map so the planner can use Index Only Scans.
VACUUM (ANALYZE) hotel_bookings;
VACUUM (ANALYZE) booking_events;
