-- Migration: Add FCM Token to users table

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS fcm_token TEXT;

COMMENT ON COLUMN public.users.fcm_token IS 'Firebase Cloud Messaging token for push notifications';
