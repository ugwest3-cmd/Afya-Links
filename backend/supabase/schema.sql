-- Afya Links MVP - Supabase PostgreSQL Schema

-- 1. Users Table (Core Auth & Roles)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone VARCHAR(20) UNIQUE NOT NULL,
    role VARCHAR(20) CHECK (role in ('ADMIN', 'CLINIC', 'PHARMACY', 'DRIVER', 'HEALTH_WORKER')) NOT NULL,
    name VARCHAR(100),
    email VARCHAR(100),
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Profiles / Verification Documents
CREATE TABLE clinic_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    business_name VARCHAR(150),
    address TEXT,
    business_reg_url TEXT,
    contact_phone VARCHAR(20)
);

CREATE TABLE pharmacy_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    business_name VARCHAR(150),
    address TEXT,
    pharmacy_license_url TEXT,
    business_reg_url TEXT,
    contact_phone VARCHAR(20)
);

CREATE TABLE driver_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    national_id_url TEXT,
    vehicle_reg_url TEXT,
    region VARCHAR(100), -- Operating region
    available_hours VARCHAR(100), -- e.g. "08:00-17:00"
    delivery_zone VARCHAR(50), -- Specific zone within region
    agreed_fee DECIMAL(10,2)
);

-- 3. Price Lists (Uploaded by Pharmacies)
CREATE TABLE price_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pharmacy_id UUID REFERENCES users(id) ON DELETE CASCADE,
    csv_url TEXT NOT NULL,
    valid_until TIMESTAMP WITH TIME ZONE NOT NULL, -- usually 48 hours from upload
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Note: In a production system, we'd parse the CSV into a "price_items" table. 
-- For MVP, we might keep it in Supabase Storage and parse on-the-fly, or load it here.
CREATE TABLE price_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    price_list_id UUID REFERENCES price_lists(id) ON DELETE CASCADE,
    sku VARCHAR(50),
    drug_name VARCHAR(150) NOT NULL,
    brand VARCHAR(100),
    strength VARCHAR(50),
    pack_size VARCHAR(50),
    unit VARCHAR(50),
    price DECIMAL(10,2) NOT NULL,
    stock_qty INT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Orders
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id UUID REFERENCES users(id) ON DELETE CASCADE,
    pharmacy_id UUID REFERENCES users(id), -- assigned after clinic accepts pharmacy's hidden price offer
    status VARCHAR(30) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACCEPTED', 'PARTIAL', 'REJECTED', 'READY_FOR_PICKUP', 'ASSIGNED', 'IN_TRANSIT', 'DELIVERED')),
    subtotal DECIMAL(10,2) DEFAULT 0,
    delivery_fee DECIMAL(10,2) DEFAULT 0,
    platform_commission DECIMAL(10,2) DEFAULT 0,
    delivery_commission DECIMAL(10,2) DEFAULT 0,
    order_code VARCHAR(10) UNIQUE, -- Generated on acceptance
    prescription_url TEXT,
    delivery_address TEXT,
    rejected_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    drug_name VARCHAR(150) NOT NULL,
    quantity INT NOT NULL,
    price_agreed DECIMAL(10,2), -- set when offer is accepted
    is_missing BOOLEAN DEFAULT false -- for 'PARTIAL' acceptance
);

-- 5. Deliveries
CREATE TABLE deliveries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES users(id),
    pickup_time TIMESTAMP WITH TIME ZONE,
    dropoff_time TIMESTAMP WITH TIME ZONE,
    driver_fee_collected DECIMAL(10,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. Invoices (Platform -> Pharmacy)
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pharmacy_id UUID REFERENCES users(id) ON DELETE CASCADE,
    total_amount DECIMAL(10,2) NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'UNPAID' CHECK (status IN ('UNPAID', 'PENDING_VERIFICATION', 'PAID', 'OVERDUE')),
    payment_proof_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Optional trigger for updated_at timestamps
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_timestamp_orders
BEFORE UPDATE ON orders
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

CREATE TRIGGER set_timestamp_invoices
BEFORE UPDATE ON invoices
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();
