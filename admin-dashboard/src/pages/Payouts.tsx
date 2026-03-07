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

interface DriverPayout {
    id: string;
    driver_id: string;
    amount: number;
    status: string;
    created_at: string;
    driver: { name: string; phone: string };
}

export const Payouts = () => {
    const [requests, setRequests] = useState<PayoutRequest[]>([]);
    const [driverRequests, setDriverRequests] = useState<DriverPayout[]>([]);
    const [alerts, setAlerts] = useState<Alert[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [activeTab, setActiveTab] = useState<'pharmacy' | 'driver'>('pharmacy');

    const fetchData = async () => {
        try {
            setLoading(true);
            const [payoutsRes, alertsRes, driversRes] = await Promise.all([
                api.get('/admin/payouts'),
                api.get('/admin/payout-alerts'),
                api.get('/admin/payouts/drivers')
            ]);

            if (payoutsRes.data.success) setRequests(payoutsRes.data.payouts || []);
            if (alertsRes.data.success) setAlerts(alertsRes.data.alerts || []);
            if (driversRes.data.success) setDriverRequests(driversRes.data.payouts || []);

        } catch (err: any) {
            setError(err.response?.data?.message || err.message || 'Failed to load payouts');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => { fetchData(); }, []);

    const handleMarkPaid = async (id: string, type: 'pharmacy' | 'driver') => {
        if (!window.confirm(`Mark this ${type} payout as paid?`)) return;
        try {
            const url = type === 'pharmacy' ? `/admin/payouts/${id}/pay` : `/admin/payouts/drivers/${id}/pay`;
            const res = await api.post(url);
            if (res.data.success) {
                alert('Success!');
                fetchData();
            }
        } catch (err: any) {
            alert(err.response?.data?.message || 'Error processing payout');
        }
    };

    if (loading) return <div className="p-8 text-center text-gray-500">Loading payout systems...</div>;

    return (
        <div className="space-y-6">
            {error && <div className="bg-red-50 text-red-600 p-4 rounded-lg">{error}</div>}

            {/* Alerts - Only for Pharmacies for now */}
            <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                <AlertCircle size={20} className="text-orange-500" /> High Balance Alerts
            </h2>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                {alerts.map(alert => (
                    <div key={alert.pharmacy_id} className="p-4 rounded-xl border-l-4 shadow-sm bg-orange-50 border-orange-400">
                        <h3 className="font-semibold text-gray-900">{alert.pharmacy?.name}</h3>
                        <p className="text-sm text-gray-500">{alert.pharmacy?.phone}</p>
                        <div className="mt-2 text-lg font-bold text-gray-800">UGX {alert.available_balance.toLocaleString()}</div>
                    </div>
                ))}
            </div>

            {/* Tabs */}
            <div className="flex border-b border-gray-200">
                <button
                    onClick={() => setActiveTab('pharmacy')}
                    className={`pb-4 px-6 text-sm font-medium transition-colors ${activeTab === 'pharmacy' ? 'border-b-2 border-green-600 text-green-600' : 'text-gray-500 hover:text-gray-700'}`}
                >
                    Pharmacy Payouts ({requests.filter(r => r.status === 'PENDING').length})
                </button>
                <button
                    onClick={() => setActiveTab('driver')}
                    className={`pb-4 px-6 text-sm font-medium transition-colors ${activeTab === 'driver' ? 'border-b-2 border-green-600 text-green-600' : 'text-gray-500 hover:text-gray-700'}`}
                >
                    Driver Payouts ({driverRequests.filter(r => r.status === 'PENDING').length})
                </button>
            </div>

            <div className="bg-white rounded-xl shadow-sm overflow-hidden border border-gray-100">
                <table className="w-full text-left">
                    <thead>
                        <tr className="bg-gray-50 text-gray-600 text-sm">
                            <th className="p-4 font-medium">Date</th>
                            <th className="p-4 font-medium">{activeTab === 'pharmacy' ? 'Pharmacy' : 'Driver'}</th>
                            <th className="p-4 font-medium">Amount</th>
                            <th className="p-4 font-medium">Status</th>
                            <th className="p-4 font-medium text-right">Action</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-100">
                        {activeTab === 'pharmacy' ? (
                            requests.length === 0 ? <tr><td colSpan={5} className="p-8 text-center">No pharmacy requests</td></tr> :
                                requests.map(req => (
                                    <tr key={req.id} className="hover:bg-gray-50/50">
                                        <td className="p-4 text-sm">{new Date(req.created_at).toLocaleDateString()}</td>
                                        <td className="p-4">
                                            <div className="font-medium">{req.pharmacy?.name}</div>
                                            <div className="text-xs text-gray-500">{req.pharmacy?.phone}</div>
                                        </td>
                                        <td className="p-4 font-bold">UGX {req.amount.toLocaleString()}</td>
                                        <td className="p-4"><span className={`px-2 py-1 rounded-full text-xs font-bold ${req.status === 'PAID' ? 'bg-green-100 text-green-700' : 'bg-amber-100 text-amber-700'}`}>{req.status}</span></td>
                                        <td className="p-4 text-right">
                                            {req.status === 'PENDING' && (
                                                <button onClick={() => handleMarkPaid(req.id, 'pharmacy')} className="bg-green-600 text-white px-3 py-1.5 rounded-lg text-sm font-bold">Mark Paid</button>
                                            )}
                                        </td>
                                    </tr>
                                ))
                        ) : (
                            driverRequests.length === 0 ? <tr><td colSpan={5} className="p-8 text-center">No driver requests</td></tr> :
                                driverRequests.map(req => (
                                    <tr key={req.id} className="hover:bg-gray-50/50">
                                        <td className="p-4 text-sm">{new Date(req.created_at).toLocaleDateString()}</td>
                                        <td className="p-4">
                                            <div className="font-medium">{req.driver?.name}</div>
                                            <div className="text-xs text-gray-500">{req.driver?.phone}</div>
                                        </td>
                                        <td className="p-4 font-bold">UGX {req.amount.toLocaleString()}</td>
                                        <td className="p-4"><span className={`px-2 py-1 rounded-full text-xs font-bold ${req.status === 'PAID' ? 'bg-green-100 text-green-700' : 'bg-amber-100 text-amber-700'}`}>{req.status}</span></td>
                                        <td className="p-4 text-right">
                                            {req.status === 'PENDING' && (
                                                <button onClick={() => handleMarkPaid(req.id, 'driver')} className="bg-green-600 text-white px-3 py-1.5 rounded-lg text-sm font-bold">Mark Paid</button>
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
