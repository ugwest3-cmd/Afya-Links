import { useState, useEffect } from 'react';
import { DollarSign, AlertCircle, CheckCircle, Clock } from 'lucide-react';
import api from '../utils/api';

interface PayoutRequest {
    id: string;
    pharmacy_id: string;
    amount: number;
    payment_method: string;
    payment_details: any;
    status: string;
    created_at: string;
    pharmacy: { name: string; email: string; phone: string };
}

interface Alert {
    pharmacy_id: string;
    available_balance: number;
    alert_level: string;
    pharmacy: { name: string; phone: string };
}

export const Payouts = () => {
    const [requests, setRequests] = useState<PayoutRequest[]>([]);
    const [alerts, setAlerts] = useState<Alert[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');

    const fetchData = async () => {
        try {
            setLoading(true);
            setError('');

            const [payoutsRes, alertsRes] = await Promise.all([
                api.get('/admin/payouts'),
                api.get('/admin/payout-alerts')
            ]);

            if (payoutsRes.data.success) setRequests(payoutsRes.data.payouts || []);
            if (alertsRes.data.success) setAlerts(alertsRes.data.alerts || []);

        } catch (err: any) {
            setError(err.response?.data?.message || err.message || 'Failed to load payouts data');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchData();
    }, []);

    const handleMarkPaid = async (id: string) => {
        if (!window.confirm('Are you sure you have already sent the funds to this pharmacy?')) return;

        try {
            const res = await api.post(`/admin/payouts/${id}/pay`);
            if (res.data.success) {
                alert('Payout marked as paid!');
                fetchData();
            } else {
                alert(res.data.message || 'Failed to update payout');
            }
        } catch (err: any) {
            alert(err.response?.data?.message || err.message || 'An error occurred');
        }
    };

    if (loading) return <div className="p-8"><div className="animate-pulse flex space-x-4"><div className="h-12 bg-slate-200 rounded w-full"></div></div></div>;

    return (
        <div className="space-y-6">
            {error && <div className="bg-red-50 text-red-600 p-4 rounded-lg">{error}</div>}

            {/* Alerts Section */}
            <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                <AlertCircle size={20} className="text-orange-500" /> High Balance Alerts
            </h2>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-8">
                {alerts.length === 0 ? (
                    <p className="text-gray-500 text-sm">No pharmacies with high unrequested balances.</p>
                ) : (
                    alerts.map(alert => (
                        <div key={alert.pharmacy_id} className={`p-4 rounded-xl border-l-4 shadow-sm ${alert.alert_level === 'Level 2' ? 'bg-red-50 border-red-500' : 'bg-orange-50 border-orange-400'}`}>
                            <div className="flex justify-between items-start">
                                <div>
                                    <h3 className="font-semibold text-gray-900">{alert.pharmacy?.name || 'Unknown Pharmacy'}</h3>
                                    <p className="text-sm text-gray-500">{alert.pharmacy?.phone}</p>
                                </div>
                                <span className={`text-xs px-2 py-1 rounded-full font-medium ${alert.alert_level === 'Level 2' ? 'bg-red-100 text-red-700' : 'bg-orange-100 text-orange-700'}`}>
                                    {alert.alert_level}
                                </span>
                            </div>
                            <div className="mt-3 text-lg font-bold text-gray-800">
                                UGX {alert.available_balance.toLocaleString()}
                            </div>
                        </div>
                    ))
                )}
            </div>

            {/* Requests Section */}
            <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                <DollarSign size={20} className="text-green-600" /> Payout Requests
            </h2>

            <div className="bg-white rounded-xl shadow-sm overflow-hidden border border-gray-100">
                <table className="w-full text-left border-collapse">
                    <thead>
                        <tr className="bg-gray-50 text-gray-600 text-sm">
                            <th className="p-4 font-medium">Date</th>
                            <th className="p-4 font-medium">Pharmacy</th>
                            <th className="p-4 font-medium">Amount</th>
                            <th className="p-4 font-medium">Method</th>
                            <th className="p-4 font-medium">Status</th>
                            <th className="p-4 font-medium text-right">Action</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-100">
                        {requests.length === 0 ? (
                            <tr>
                                <td colSpan={6} className="p-8 text-center text-gray-500">No payout requests found</td>
                            </tr>
                        ) : (
                            requests.map(req => (
                                <tr key={req.id} className="hover:bg-gray-50/50 transition-colors">
                                    <td className="p-4 text-sm text-gray-600">
                                        {new Date(req.created_at).toLocaleDateString()}
                                    </td>
                                    <td className="p-4">
                                        <div className="font-medium text-gray-900">{req.pharmacy?.name}</div>
                                        <div className="text-xs text-gray-500">{req.pharmacy?.phone}</div>
                                    </td>
                                    <td className="p-4 font-semibold text-gray-900">
                                        UGX {req.amount.toLocaleString()}
                                    </td>
                                    <td className="p-4">
                                        <div className="text-sm font-medium text-gray-800">{req.payment_method}</div>
                                        <div className="text-xs text-gray-500 max-w-xs truncate" title={JSON.stringify(req.payment_details)}>
                                            {Object.values(req.payment_details || {}).join(' - ')}
                                        </div>
                                    </td>
                                    <td className="p-4">
                                        {req.status === 'PENDING' ? (
                                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-amber-50 text-amber-700 border border-amber-200/50">
                                                <Clock size={12} /> Pending
                                            </span>
                                        ) : req.status === 'PAID' ? (
                                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-emerald-50 text-emerald-700 border border-emerald-200/50">
                                                <CheckCircle size={12} /> Paid
                                            </span>
                                        ) : (
                                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-red-50 text-red-700 border border-red-200/50">
                                                {req.status}
                                            </span>
                                        )}
                                    </td>
                                    <td className="p-4 text-right">
                                        {req.status === 'PENDING' && (
                                            <button
                                                onClick={() => handleMarkPaid(req.id)}
                                                className="px-3 py-1.5 bg-green-600 hover:bg-green-700 text-white text-sm font-medium rounded-lg transition-colors"
                                            >
                                                Mark as Paid
                                            </button>
                                        )}
                                    </td>
                                </tr>
                            ))
                        )}
                    </tbody>
                </table>
            </div>
        </div>
    );
};
