import { useState, useEffect } from 'react';
import { Package, RefreshCw } from 'lucide-react';

export const Orders = () => {
    const [orders, setOrders] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);
    const token = localStorage.getItem('afyalinks_admin_token');

    const fetchOrders = async () => {
        try {
            setLoading(true);
            const res = await fetch('http://localhost:5000/api/admin/orders', {
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            });
            const data = await res.json();
            if (data.success) {
                setOrders(data.orders);
            }
        } catch (error) {
            console.error('Failed to fetch orders:', error);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (token) fetchOrders();
    }, [token]);

    const getStatusStyle = (status: string) => {
        switch (status) {
            case 'DELIVERED': return { background: 'rgba(34, 197, 94, 0.1)', color: 'var(--status-success)' };
            case 'ASSIGNED': return { background: 'rgba(59, 130, 246, 0.1)', color: 'var(--accent-primary)' };
            case 'REJECTED': return { background: 'rgba(239, 68, 68, 0.1)', color: 'var(--status-danger)' };
            default: return { background: 'rgba(234, 179, 8, 0.1)', color: 'var(--status-warning)' };
        }
    };

    return (
        <div className="fade-in">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
                <div>
                    <h2 className="text-h2" style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <Package size={28} style={{ color: 'var(--accent-primary)' }} />
                        Order Orchestration
                    </h2>
                    <p className="text-muted">Monitor global order statuses and logistics.</p>
                </div>
                <button
                    onClick={fetchOrders}
                    className="btn btn-secondary"
                    disabled={loading}
                >
                    <RefreshCw size={18} className={loading ? 'spin' : ''} />
                    Refresh
                </button>
            </div>

            <div className="card">
                <div style={{ overflowX: 'auto' }}>
                    <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
                        <thead>
                            <tr style={{ borderBottom: '1px solid var(--border-color)', color: 'var(--text-secondary)' }}>
                                <th style={{ padding: '1rem', fontWeight: 500 }}>Order ID</th>
                                <th style={{ padding: '1rem', fontWeight: 500 }}>Code</th>
                                <th style={{ padding: '1rem', fontWeight: 500 }}>Status</th>
                                <th style={{ padding: '1rem', fontWeight: 500 }}>Value (UGX)</th>
                                <th style={{ padding: '1rem', fontWeight: 500 }}>Date</th>
                            </tr>
                        </thead>
                        <tbody>
                            {orders.length === 0 ? (
                                <tr>
                                    <td colSpan={5} style={{ padding: '2rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                                        No active orders found.
                                    </td>
                                </tr>
                            ) : (
                                orders.map((order) => (
                                    <tr key={order.id} style={{ borderBottom: '1px solid var(--border-color)' }}>
                                        <td style={{ padding: '1rem', fontFamily: 'monospace' }}>
                                            {order.id.split('-')[0]}...
                                        </td>
                                        <td style={{ padding: '1rem', fontFamily: 'monospace', fontWeight: 'bold' }}>
                                            {order.order_code || '---'}
                                        </td>
                                        <td style={{ padding: '1rem' }}>
                                            <span style={{
                                                padding: '4px 12px',
                                                borderRadius: '20px',
                                                fontSize: '0.85rem',
                                                fontWeight: 600,
                                                ...getStatusStyle(order.status)
                                            }}>
                                                {order.status}
                                            </span>
                                        </td>
                                        <td style={{ padding: '1rem', fontWeight: 500 }}>
                                            {order.subtotal?.toLocaleString() ?? '---'}
                                        </td>
                                        <td style={{ padding: '1rem', color: 'var(--text-secondary)' }}>
                                            {new Date(order.created_at).toLocaleDateString()}
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    );
};
