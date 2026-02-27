import { Request, Response } from 'express';
import { supabase } from '../config/supabase';
import { generateToken } from '../utils/jwt';
import { sendSMS } from '../utils/sms';

// In-memory OTP store for MVP Pilot. 
// Format: Map<phone, { otp: string, expiresAt: number }>
const otpStore = new Map<string, { otp: string, expiresAt: number }>();

export const requestOtp = async (req: Request, res: Response): Promise<void> => {
    try {
        const { phone } = req.body;

        if (!phone) {
            res.status(400).json({ success: false, message: 'Phone number is required' });
            return;
        }

        // Generate random 6 digit OTP
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        const expiresAt = Date.now() + 5 * 60 * 1000; // 5 mins

        otpStore.set(phone, { otp, expiresAt });

        // Send actual SMS via Africa's Talking
        const smsResponse = await sendSMS([phone], `Your AfyaLinks verification code is: ${otp}. Valid for 5 minutes.`);

        if (!smsResponse.success) {
            console.error('[SMS Failed]', smsResponse.error);
        } else {
            console.log(`[SMS Sent] OTP to ${phone}`);
        }

        res.status(200).json({
            success: true,
            message: 'OTP sent successfully',
        });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const verifyOtp = async (req: Request, res: Response): Promise<void> => {
    try {
        const { phone, otp, role } = req.body;

        if (!phone || !otp) {
            res.status(400).json({ success: false, message: 'Phone and OTP are required' });
            return;
        }

        const record = otpStore.get(phone);
        if (!record) {
            res.status(400).json({ success: false, message: 'OTP not requested or expired' });
            return;
        }

        if (Date.now() > record.expiresAt) {
            otpStore.delete(phone);
            res.status(400).json({ success: false, message: 'OTP expired' });
            return;
        }

        if (record.otp !== otp) {
            res.status(400).json({ success: false, message: 'Invalid OTP' });
            return;
        }

        // OTP matches, delete it
        otpStore.delete(phone);

        // Check if user exists in Supabase
        let { data: user, error: fetchError } = await supabase
            .from('users')
            .select('*')
            .eq('phone', phone)
            .single();

        if (!user) {
            // Create user if they don't exist
            if (!role) {
                res.status(400).json({ success: false, message: 'Role is required for new registration (CLINIC, PHARMACY, DRIVER, HEALTH_WORKER)' });
                return;
            }

            const { data: newUser, error: insertError } = await supabase
                .from('users')
                .insert([{ phone, role }])
                .select()
                .single();

            if (insertError) {
                res.status(500).json({ success: false, message: 'Failed to create user' });
                return;
            }
            user = newUser;
        }

        // Generate JWT
        const token = generateToken({ id: user.id, role: user.role });

        res.status(200).json({
            success: true,
            message: 'Authentication successful',
            token,
            user
        });

    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};
