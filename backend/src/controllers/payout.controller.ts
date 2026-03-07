import { Response } from 'express';
import { AuthRequest } from '../middlewares/authMiddleware';
import { supabase } from '../config/supabase';
import { sendNotification, notifyAdmins } from '../services/notification.service';

/**
 * Pharmacy: Request a payout
 * POST /api/pharmacies/payouts
 */
export const requestPayout = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const pharmacyId = req.user?.id;
        if (!pharmacyId) {
            res.status(401).json({ success: false, message: 'Unauthorized' });
            return;
        }

        // 1. Fetch wallet balance and payment method
        const { data: wallet } = await supabase
            .from('pharmacy_wallet')
            .select('available_balance')
            .eq('pharmacy_id', pharmacyId)
            .single();

        const balance = wallet ? Number(wallet.available_balance) : 0;

        if (balance < 500000) {
            res.status(400).json({ success: false, message: `Minimum payout is 500,000 UGX. Current balance: ${balance}` });
            return;
        }

        // 2. Fetch preferred payment method
        const { data: profile } = await supabase
            .from('pharmacy_profiles')
            .select('preferred_payout_method, payout_details, business_name')
            .eq('user_id', pharmacyId)
            .single();

        const paymentMethod = profile?.preferred_payout_method;
        if (!paymentMethod) {
            res.status(400).json({ success: false, message: 'Please setup a preferred payout method in your profile first.' });
            return;
        }

        // 3. Check 24-hour limit
        const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
        const { data: recentRequests } = await supabase
            .from('payout_requests')
            .select('id')
            .eq('pharmacy_id', pharmacyId)
            .gte('created_at', twentyFourHoursAgo);

        if (recentRequests && recentRequests.length > 0) {
            res.status(429).json({ success: false, message: 'You can only request one payout every 24 hours.' });
            return;
        }

        // 4. Create payout request and deduct balance
        // Note: Realistically, this should be an atomic transaction/RPC.
        const newBalance = balance - balance; // Assuming they withdraw everything available

        await supabase
            .from('pharmacy_wallet')
            .update({ available_balance: newBalance, pending_balance: balance }) // optional: track pending
            .eq('pharmacy_id', pharmacyId);

        const { data: payoutRequest, error: payoutError } = await supabase
            .from('payout_requests')
            .insert({
                pharmacy_id: pharmacyId,
                amount: balance,
                payment_method: paymentMethod,
                payment_details: profile?.payout_details || {},
                status: 'PENDING'
            })
            .select()
            .single();

        if (payoutError) throw payoutError;

        // 5. Notify Admin (Simulated email via DB log / notification system for now)
        // In reality you would use SendGrid or similar to email the admin.
        console.log(`[Email] Subject: New Pharmacy Payout Request from ${profile?.business_name || pharmacyId}. Amount: UGX ${balance}`);

        res.status(201).json({ success: true, message: 'Payout requested successfully', payout_request: payoutRequest });

        // Notify Pharmacy (Push only)
        sendNotification({
            userId: pharmacyId,
            title: '💸 Payout Request Received',
            body: `Your request for UGX ${balance} has been received and is pending admin review.`,
            type: 'PAYOUT_REQUESTED'
        });

        // Notify Admins
        notifyAdmins({
            title: '📢 New Payout Request',
            body: `Pharmacy ${profile?.business_name || pharmacyId} has requested a payout of UGX ${balance}.`,
            type: 'PAYOUT_REQUEST_ADMIN'
        });

    } catch (error: any) {
        console.error('[Payout Request] Error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * Pharmacy: Get Payout History
 * GET /api/pharmacies/payouts
 */
export const getPayoutHistory = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const pharmacyId = req.user?.id;
        const { data: payouts, error } = await supabase
            .from('payout_requests')
            .select('*')
            .eq('pharmacy_id', pharmacyId)
            .order('created_at', { ascending: false });

        if (error) throw error;

        const { data: wallet } = await supabase
            .from('pharmacy_wallet')
            .select('available_balance, total_paid_out')
            .eq('pharmacy_id', pharmacyId)
            .single();

        res.status(200).json({ success: true, payouts, wallet });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * Admin: Get All Payout Requests
 * GET /api/admin/payouts
 */
export const adminGetPayoutRequests = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { data: payouts, error } = await supabase
            .from('payout_requests')
            .select(`
                *,
                pharmacy:users!payout_requests_pharmacy_id_fkey(name, email, phone)
            `)
            .order('created_at', { ascending: false });

        if (error) throw error;

        res.status(200).json({ success: true, payouts });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * Admin: Get high balance warning limits
 * GET /api/admin/payout-alerts
 */
export const adminGetPayoutAlerts = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { data: wallets, error } = await supabase
            .from('pharmacy_wallet')
            .select(`
                pharmacy_id,
                available_balance,
                pharmacy:users!pharmacy_wallet_pharmacy_id_fkey(name, phone)
            `)
            .gte('available_balance', 500000)
            .order('available_balance', { ascending: false });

        if (error) throw error;

        const alerts = wallets.map((w: any) => ({
            ...w,
            alert_level: w.available_balance >= 1000000 ? 'Level 2' : 'Level 1'
        }));

        res.status(200).json({ success: true, alerts });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
}

/**
 * Admin: Mark Payout as Paid
 */
export const adminMarkPayoutPaid = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { id } = req.params;
        const { data: request } = await supabase.from('payout_requests').select('*').eq('id', id).single();

        if (!request || request.status === 'PAID') {
            res.status(400).json({ success: false, message: 'Invalid or already paid request' });
            return;
        }

        // 1. Update status & wallet
        await supabase.from('payout_requests').update({ status: 'PAID', updated_at: new Date().toISOString() }).eq('id', id);

        const { data: wallet } = await supabase.from('pharmacy_wallet').select('*').eq('pharmacy_id', request.pharmacy_id).single();
        if (wallet) {
            await supabase.from('pharmacy_wallet').update({
                pending_balance: wallet.pending_balance - request.amount,
                total_paid_out: wallet.total_paid_out + request.amount,
                lifetime_payouts: wallet.lifetime_payouts + 1
            }).eq('pharmacy_id', request.pharmacy_id);
        }

        // 2. Create Invoice Record
        await supabase.from('invoices').insert({
            pharmacy_id: request.pharmacy_id,
            total_amount: request.amount,
            status: 'PAID',
            type: 'PAYOUT'
        });

        res.status(200).json({ success: true, message: 'Payout processed' });

        sendNotification({
            userId: request.pharmacy_id,
            title: '💸 Payout Processed',
            body: `Your payout of UGX ${request.amount} has been processed.`,
            type: 'PAYOUT_PAID',
            sendSMS: true
        });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

/**
 * Admin: Get Driver Payout Requests
 */
export const adminGetDriverPayoutRequests = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { data: payouts } = await supabase
            .from('driver_payouts')
            .select('*, driver:users!driver_payouts_driver_id_fkey(name, phone)')
            .order('created_at', { ascending: false });
        res.status(200).json({ success: true, payouts });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

/**
 * Admin: Mark Driver Payout as Paid
 */
export const adminMarkDriverPayoutPaid = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { id } = req.params;
        const { data: request } = await supabase.from('driver_payouts').select('*').eq('id', id).single();

        if (!request || request.status === 'PAID') {
            res.status(400).json({ success: false, message: 'Invalid request' });
            return;
        }

        await supabase.from('driver_payouts').update({ status: 'PAID' }).eq('id', id);

        // Create Invoice
        await supabase.from('invoices').insert({
            driver_id: request.driver_id,
            total_amount: request.amount,
            status: 'PAID',
            type: 'PAYOUT'
        });

        res.status(200).json({ success: true, message: 'Driver payout processed' });

        sendNotification({
            userId: request.driver_id,
            title: '💸 Payout Processed',
            body: `Your delivery payout of UGX ${request.amount} is ready.`,
            type: 'PAYOUT_PAID',
            sendSMS: true
        });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};
