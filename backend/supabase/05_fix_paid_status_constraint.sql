-- Migration 05: Add 'PAID' to orders.status constraint
-- The original constraint was missing 'PAID' which caused all payment
-- confirmations to silently fail at the DB level.

-- Drop the old constraint
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;

-- Re-add it WITH 'PAID' and 'AWAITING_PAYMENT' included
ALTER TABLE orders ADD CONSTRAINT orders_status_check 
    CHECK (status IN (
        'PENDING',
        'AWAITING_PAYMENT',
        'PAID',              -- ← was missing, caused silent payment failures
        'PAID_READY',
        'ACCEPTED',
        'PARTIAL',
        'REJECTED',
        'READY_FOR_PICKUP',
        'ASSIGNED',
        'IN_TRANSIT',
        'OUT_FOR_DELIVERY',
        'DELIVERED',
        'DELIVERY_CONFIRMED',
        'COMPLETED',
        'DELIVERY_FAILED',
        'DISPUTE',
        'REFUNDED'
    ));
