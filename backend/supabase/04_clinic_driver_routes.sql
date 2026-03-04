-- Migration 04: Clinic-Driver Route Assignments
-- Allows admin to assign a specific driver to a clinic route and set the delivery fee for that route.
-- When a CLINIC places an order, the system auto-assigns the driver from this table.

CREATE TABLE IF NOT EXISTS clinic_driver_routes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    delivery_fee DECIMAL(10,2) NOT NULL DEFAULT 0,
    notes TEXT,                          -- e.g. "Kampala North route, daily"
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (clinic_id)                   -- One active driver per clinic at a time
);

-- Trigger to auto-update updated_at
CREATE TRIGGER set_timestamp_clinic_driver_routes
BEFORE UPDATE ON clinic_driver_routes
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

-- Index for fast lookup during order creation
CREATE INDEX IF NOT EXISTS idx_clinic_driver_routes_clinic_id ON clinic_driver_routes(clinic_id);
