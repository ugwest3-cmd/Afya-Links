-- 1. Add new fields to driver_profiles
ALTER TABLE driver_profiles 
ADD COLUMN IF NOT EXISTS national_id_number VARCHAR(50),
ADD COLUMN IF NOT EXISTS vehicle_type VARCHAR(50),
ADD COLUMN IF NOT EXISTS license_plate_number VARCHAR(50),
ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS preferred_payout_method VARCHAR(50),
ADD COLUMN IF NOT EXISTS payout_details JSONB,
ADD COLUMN IF NOT EXISTS wallet_balance DECIMAL(10,2) DEFAULT 0;

-- 2. Add QR fields and timeout info to orders
ALTER TABLE orders
ADD COLUMN IF NOT EXISTS pickup_qr VARCHAR(100),
ADD COLUMN IF NOT EXISTS delivery_qr VARCHAR(100),
ADD COLUMN IF NOT EXISTS driver_assigned_at TIMESTAMP WITH TIME ZONE;

-- 3. Create driver_payouts table
CREATE TABLE IF NOT EXISTS public.driver_payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(50),
    payment_details JSONB,
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PAID', 'REJECTED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Trigger for driver_payouts updated_at
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'set_timestamp_driver_payouts') THEN
        CREATE TRIGGER set_timestamp_driver_payouts
        BEFORE UPDATE ON driver_payouts
        FOR EACH ROW
        EXECUTE PROCEDURE trigger_set_timestamp();
    END IF;
END
$$;
