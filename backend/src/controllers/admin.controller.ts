import { Response } from 'express';
import { AuthRequest } from '../middlewares/authMiddleware';
import { supabase } from '../config/supabase';

// 1. Get Pending Verifications
export const getPendingVerifications = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { data: users, error } = await supabase
            .from('users')
            .select('id, name, email, phone, role, is_verified, created_at')
            .eq('is_verified', false);

        if (error) throw error;

        res.status(200).json({ success: true, pending_users: users });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

// 2. Approve User
export const approveUser = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { id: targetUserId } = req.params;

        const { error } = await supabase
            .from('users')
            .update({ is_verified: true })
            .eq('id', targetUserId);

        if (error) throw error;

        res.status(200).json({ success: true, message: 'User approved successfully' });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

// 3. Get Invoices
export const getInvoices = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { data: invoices, error } = await supabase
            .from('invoices')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) throw error;

        res.status(200).json({ success: true, invoices });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

// 4. Verify Payment
export const verifyPayment = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { id: invoiceId } = req.params;

        const { error } = await supabase
            .from('invoices')
            .update({ status: 'PAID' })
            .eq('id', invoiceId);

        if (error) throw error;

        res.status(200).json({ success: true, message: 'Payment verified successfully' });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}
