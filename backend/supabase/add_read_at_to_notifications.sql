-- Migration: Add read_at column to notifications table
-- Run this in your Supabase SQL Editor

-- 1. Add read_at column (nullable - only set when notification is marked as read)
ALTER TABLE notifications
ADD COLUMN IF NOT EXISTS read_at TIMESTAMP WITH TIME ZONE;

-- 2. For any existing read notifications, backfill read_at with their created_at
--    (We can't know when they were actually read, so we use created_at as a safe default)
UPDATE notifications
SET read_at = created_at
WHERE is_read = true AND read_at IS NULL;
