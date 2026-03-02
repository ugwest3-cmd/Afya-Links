-- Afya Links - 03_add_missing_order_columns.sql
-- Run this in your Supabase SQL Editor
-- Adds driver_commission and pharmacy_commission columns that the backend tries to write
-- but were missing from the original schema and the 02_pesapal_escrow_migration.sql

ALTER TABLE orders
    ADD COLUMN IF NOT EXISTS pharmacy_commission DECIMAL(10,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS driver_commission DECIMAL(10,2) DEFAULT 0;
