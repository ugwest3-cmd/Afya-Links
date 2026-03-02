-- Afya Links - 02_pesapal_escrow_migration.sql
-- Run this in your Supabase SQL Editor to update the database for Pesapal Mobile Money Integration

-- 1. Remove old CHECK constraint on orders.status
-- We need to drop the existing constraint. Let's find its name first. Default is usually something like 'orders_status_check'
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;

-- 2. Add new ledger columns to 'orders' table
ALTER TABLE orders 
    ADD COLUMN IF NOT EXISTS total_payable DECIMAL(10,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS pharmacy_net DECIMAL(10,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS driver_net DECIMAL(10,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS total_platform_revenue DECIMAL(10,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS payment_status VARCHAR(30) DEFAULT 'AWAITING_PAYMENT' CHECK (payment_status IN ('AWAITING_PAYMENT', 'VERIFIED', 'PAYMENT_FAILED')),
    ADD COLUMN IF NOT EXISTS escrow_status VARCHAR(30) DEFAULT 'NOT_FUNDED' CHECK (escrow_status IN ('NOT_FUNDED', 'LOCKED', 'RELEASED', 'RETURNED')),
    ADD COLUMN IF NOT EXISTS payout_status VARCHAR(30),
    ADD COLUMN IF NOT EXISTS driver_id UUID REFERENCES users(id);

-- 3. Add the new comprehensive CHECK constraint for orders.status
ALTER TABLE orders ADD CONSTRAINT orders_status_check 
    CHECK (status IN (
        'PENDING', 
        'AWAITING_PAYMENT', 
        'PAID_READY', 
        'READY_FOR_PICKUP', 
        'OUT_FOR_DELIVERY', 
        'DELIVERY_CONFIRMED', 
        'COMPLETED', 
        'DELIVERY_FAILED', 
        'DISPUTE', 
        'REFUNDED',
        'ACCEPTED', -- Legacy
        'PARTIAL', -- Legacy
        'REJECTED', -- Legacy
        'ASSIGNED', -- Legacy
        'IN_TRANSIT', -- Legacy
        'DELIVERED' -- Legacy
    ));

-- 4. Create pesapal_transactions table to log all Webhooks/IPN calls
CREATE TABLE IF NOT EXISTS pesapal_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    tracking_id VARCHAR(100) UNIQUE NOT NULL, -- Pesapal unique trans ID
    merchant_reference VARCHAR(100) NOT NULL, -- Our Order ID or Code
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(10) DEFAULT 'UGX',
    payment_method VARCHAR(50),
    payment_status_code INT,
    payment_status_description VARCHAR(100),
    ipn_notified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Trigger for pesapal_transactions
CREATE TRIGGER set_timestamp_pesapal
BEFORE UPDATE ON pesapal_transactions
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();
