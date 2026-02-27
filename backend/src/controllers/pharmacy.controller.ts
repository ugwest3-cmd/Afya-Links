import { Response } from 'express';
import { AuthRequest } from '../middlewares/authMiddleware';
import { supabase } from '../config/supabase';
import { uploadFileToSupabase } from '../utils/storage';
import csvParser from 'csv-parser';
import { Readable } from 'stream';
import { assignDriverAndNotify } from '../utils/driverAssignment';

export const uploadPriceList = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const pharmacyId = req.user?.id;
        const file = req.file;

        if (!file) {
            res.status(400).json({ success: false, message: 'CSV file is required' });
            return;
        }

        if (file.mimetype !== 'text/csv' && file.mimetype !== 'application/vnd.ms-excel') {
            res.status(400).json({ success: false, message: 'Only CSV files are allowed' });
            return;
        }

        let csvUrl = '';
        try {
            csvUrl = await uploadFileToSupabase('price-lists', file, `pharmacies/${pharmacyId}`);
        } catch (e: any) {
            res.status(500).json({ success: false, message: 'Storage upload failed', error: e.message });
            return;
        }

        const validUntil = new Date();
        validUntil.setHours(validUntil.getHours() + 48);

        const { data: priceList, error: plError } = await supabase
            .from('price_lists')
            .insert([{ pharmacy_id: pharmacyId, csv_url: csvUrl, valid_until: validUntil }])
            .select()
            .single();

        if (plError || !priceList) throw plError || new Error('Failed to create price_list record');

        const results: any[] = [];
        const stream = Readable.from(file.buffer);

        stream
            .pipe(csvParser())
            .on('data', (data) => {
                if (data.drug_name && data.price) {
                    results.push({
                        price_list_id: priceList.id,
                        sku: data.sku || null,
                        drug_name: data.drug_name,
                        brand: data.brand || null,
                        strength: data.strength || null,
                        pack_size: data.pack_size || null,
                        unit: data.unit || null,
                        price: parseFloat(data.price),
                        stock_qty: data.stock_qty ? parseInt(data.stock_qty) : null,
                    });
                }
            })
            .on('end', async () => {
                if (results.length > 0) {
                    const { error: piError } = await supabase.from('price_items').insert(results);
                    if (piError) console.error('Failed to insert price items', piError);
                }

                res.status(200).json({
                    success: true,
                    message: 'Price list uploaded and parsed successfully',
                    items_count: results.length,
                    valid_until: validUntil,
                    csv_url: csvUrl
                });
            })
            .on('error', (error) => {
                res.status(500).json({ success: false, message: 'Error parsing CSV', error: error.message });
            });

    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

const generateOrderCode = () => {
    return Math.random().toString(36).substring(2, 8).toUpperCase();
};

export const respondToOrder = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const pharmacyId = req.user?.id;
        const orderId = String(req.params.id);
        const { status, rejected_reason } = req.body;

        if (!['ACCEPTED', 'PARTIAL', 'REJECTED'].includes(status)) {
            res.status(400).json({ success: false, message: 'Invalid status' });
            return;
        }

        const { data: order, error: orderError } = await supabase
            .from('orders')
            .select('id, status')
            .eq('id', orderId)
            .eq('pharmacy_id', String(pharmacyId))
            .single();

        if (orderError || !order) {
            res.status(404).json({ success: false, message: 'Order not found or not assigned to you' });
            return;
        }

        if (order.status !== 'PENDING') {
            res.status(400).json({ success: false, message: `Order is already ${order.status}` });
            return;
        }

        let updateData: any = { status };
        if (status === 'REJECTED') {
            updateData.rejected_reason = rejected_reason || 'No reason provided';
        } else {
            updateData.order_code = generateOrderCode();
        }

        const { error: updateError } = await supabase
            .from('orders')
            .update(updateData)
            .eq('id', orderId);

        if (updateError) throw updateError;

        if (status === 'ACCEPTED' || status === 'PARTIAL') {
            console.log(`[Driver Assignment] Order ${orderId} Accepted. Order Code: ${updateData.order_code}`);
            assignDriverAndNotify(orderId, updateData.order_code).catch(console.error);
        }

        res.status(200).json({
            success: true,
            message: `Order marked as ${status}`,
            order_code: updateData.order_code
        });

    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// Handle Payment proof uploads by pharmacy
export const uploadPaymentProof = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const pharmacyId = String(req.user?.id);
        const invoiceId = String(req.params.id);
        const file = req.file;

        if (!file) {
            res.status(400).json({ success: false, message: 'Payment proof screenshot is required' });
            return;
        }

        let proofUrl = '';
        try {
            proofUrl = await uploadFileToSupabase('verification-docs', file, `invoices/${invoiceId}`);
        } catch (e: any) {
            res.status(500).json({ success: false, message: 'Storage upload failed', error: e.message });
            return;
        }

        const { error } = await supabase
            .from('invoices')
            .update({ payment_proof_url: proofUrl, status: 'PENDING_VERIFICATION' })
            .eq('id', invoiceId)
            .eq('pharmacy_id', pharmacyId);

        if (error) throw error;

        res.status(200).json({ success: true, message: 'Payment proof uploaded successfully. Pending admin review.' });

    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};
