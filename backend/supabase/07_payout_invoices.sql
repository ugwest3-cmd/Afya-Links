-- Add type and driver_id to invoices
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS type VARCHAR(20) DEFAULT 'ORDER' CHECK (type IN ('ORDER', 'PAYOUT'));
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS driver_id UUID REFERENCES users(id) ON DELETE CASCADE;

-- Update status check for invoices
ALTER TABLE invoices DROP CONSTRAINT IF EXISTS invoices_status_check;
ALTER TABLE invoices ADD CONSTRAINT invoices_status_check CHECK (status IN ('UNPAID', 'PENDING_VERIFICATION', 'PAID', 'OVERDUE'));

-- Period end/start can be null for payout invoices
ALTER TABLE invoices ALTER COLUMN period_start DROP NOT NULL;
ALTER TABLE invoices ALTER COLUMN period_end DROP NOT NULL;

-- Driver Payouts Table
CREATE TABLE IF NOT EXISTS driver_payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(15,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PAID', 'REJECTED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TRIGGER set_timestamp_driver_payouts
BEFORE UPDATE ON driver_payouts
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();
