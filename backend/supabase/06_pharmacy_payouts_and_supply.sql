-- Pharmacy wallet for payouts
CREATE TABLE IF NOT EXISTS pharmacy_wallet (
    pharmacy_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    available_balance DECIMAL(15,2) DEFAULT 0,
    withdrawable_balance DECIMAL(15,2) GENERATED ALWAYS AS (available_balance) STORED,
    pending_balance DECIMAL(15,2) DEFAULT 0,
    awaiting_confirmation DECIMAL(15,2) DEFAULT 0,
    total_paid_out DECIMAL(15,2) DEFAULT 0,
    lifetime_payouts INT DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Payout requests
CREATE TABLE IF NOT EXISTS payout_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pharmacy_id UUID REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(15,2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    payment_details JSONB,
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PAID', 'REJECTED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Clinics specify preferred supply towns (e.g., Mbarara, Kampala)
ALTER TABLE clinic_profiles ADD COLUMN IF NOT EXISTS preferred_supply_towns TEXT[];

-- Pharmacies specify the areas they supply
ALTER TABLE pharmacy_profiles ADD COLUMN IF NOT EXISTS supply_areas TEXT[];
ALTER TABLE pharmacy_profiles ADD COLUMN IF NOT EXISTS preferred_payout_method VARCHAR(50);
ALTER TABLE pharmacy_profiles ADD COLUMN IF NOT EXISTS payout_details JSONB;

-- Triggers for updated_at
CREATE TRIGGER set_timestamp_pharmacy_wallet
BEFORE UPDATE ON pharmacy_wallet
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

CREATE TRIGGER set_timestamp_payout_requests
BEFORE UPDATE ON payout_requests
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();
