-- 1. Create System Settings Table
CREATE TABLE IF NOT EXISTS public.system_settings (
    key VARCHAR(100) PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Insert Default Platform Settings
INSERT INTO public.system_settings (key, value)
VALUES ('commissions', '{"pharmacy_percent": 8, "driver_percent": 15, "min_payout": 500000}')
ON CONFLICT (key) DO NOTHING;

-- 3. Create Driver Locations Table (for Tracking)
CREATE TABLE IF NOT EXISTS public.driver_locations (
    driver_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Enable Row Level Security (Optional but recommended)
ALTER TABLE public.driver_locations ENABLE ROW LEVEL SECURITY;
