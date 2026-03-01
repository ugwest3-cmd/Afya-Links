import { useState, useEffect, useMemo } from 'react';
import { Package, RefreshCw, Search } from 'lucide-react';
import api from '../utils/api';

const STATUS_BADGE: Record<string, string> = {
    PENDING: 'badge-warning',
    ASSIGNED: 'badge-info',
    DELIVERED: 'badge-success',
    REJECTED: 'badge-danger',
};

const FILTER_TABS = ['All', 'PENDING', 'ASSIGNED', 'DELIVERED', 'REJECTED'];

export const Orders = () => {
    const [orders, setOrders] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);
    const [activeFilter, setActiveFilter] = useState('All');
    const [search, setSearch] = useState('');

    const fetchOrders = async () => {
        try {
            setLoading(true);
            const res = await api.get('/admin/orders');
            if (res.data.success) setOrders(res.data.orders);
        } catch (error) {
            console.error('Failed to fetch orders:', error);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => { fetchOrders(); }, []);

    const filtered = useMemo(() => {
        return orders.filter(o => {
            const statusMatch = activeFilter === 'All' || o.status === activeFilter;
            const searchMatch = !search || o.order_code?.toLowerCase().includes(search.toLowerCase()) || o.id?.includes(search);
            return statusMatch && searchMatch;
        });
    }, [orders, activeFilter, search]);

    return (
        <div className="fade-in">
            <div className="page-header">
                <div className="page-header-left">
                    <h2><Package size={22} style={{ color: 'var(--accent-primary)' }} /> Order Orchestration</h2>
                    <p>Monitor all platform orders in real-time</p>
                </div>
                <button className="btn btn-secondary" onClick={fetchOrders} disabled={loading}>
                    <RefreshCw size={15} className={loading ? 'spin' : ''} />
                    Refresh
                </button>
            </div>

            {/* Controls */}
            <div style={{ display: 'flex', gap: '1rem', alignItems: 'center', marginBottom: '1.25rem', flexWrap: 'wrap' }}>
                <div className="filter-tabs">
                    {FILTER_TABS.map(f => (
                        <button key={f} className={`filter-tab ${activeFilter === f ? 'active' : ''}`} onClick={() => setActiveFilter(f)}>
                            {f === 'All' ? `All (${orders.length})` : f}
                        </button>
                    ))}
                </div>
                <div className="search-bar" style={{ marginLeft: 'auto' }}>
                    <Search size={14} color="var(--text-secondary)" />
                    <input
                        placeholder="Search by code or ID..."
                        value={search}
                        onChange={e => setSearch(e.target.value)}
                    />
                </div>
            </div>

            <div className="table-container">
                <table className="data-table">
                    <thead>
                        <tr>
                            <th>Order ID</th>
                            <th>Code</th>
                            <th>Status</th>
                            <th>Value (UGX)</th>
                            <th>Delivery Address</th>
                            <th>Date</th>
                        </tr>
                    </thead>
                    <tbody>
                        {loading ? (
                            <tr><td colSpan={6} style={{ textAlign: 'center', padding: '3rem', color: 'var(--text-secondary)' }}><RefreshCw className="spin" size={20} style={{ margin: '0 auto', display: 'block' }} /></td></tr>
                        ) : filtered.length === 0 ? (
                            <tr>
                                <td colSpan={6}>
                                    <div className="empty-state">
                                        <Package size={42} />
                                        <p>No orders found{activeFilter !== 'All' ? ` with status "${activeFilter}"` : ''}.</p>
                                    </div>
                                </td>
                            </tr>
                        ) : filtered.map(order => (
                            <tr key={order.id}>
                                <td className="font-mono" style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>{order.id.split('-')[0]}…</td>
                                <td className="font-mono" style={{ fontWeight: 700, fontSize: '0.95rem' }}>{order.order_code || '—'}</td>
                                <td><span className={`badge ${STATUS_BADGE[order.status] ?? 'badge-info'}`}>{order.status}</span></td>
                                <td style={{ fontWeight: 500 }}>{order.subtotal?.toLocaleString() ?? '—'}</td>
                                <td style={{ color: 'var(--text-secondary)', fontSize: '0.85rem', maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{order.delivery_address || '—'}</td>
                                <td style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>{new Date(order.created_at).toLocaleDateString()}</td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>
        </div>
    );
};
