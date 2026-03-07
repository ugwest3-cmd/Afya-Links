import { useState, useEffect, useMemo } from 'react';
import {
    Package, RefreshCw, Search, ChevronRight,
    Clock, CheckCircle, Truck, Info, Calendar,
    MapPin, Store, Building2, ExternalLink
} from 'lucide-react';
import api from '../utils/api';

const STATUS_BADGE: Record<string, string> = {
    PENDING: 'badge-warning',
    ASSIGNED: 'badge-info',
    READY_FOR_PICKUP: 'badge-purple',
    IN_TRANSIT: 'badge-info',
    DELIVERED: 'badge-success',
    REJECTED: 'badge-danger',
    CANCELLED: 'badge-secondary',
};

const FILTER_TABS = ['All', 'PENDING', 'ASSIGNED', 'IN_TRANSIT', 'DELIVERED'];

export const Orders = () => {
    const [orders, setOrders] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);
    const [activeFilter, setActiveFilter] = useState('All');
    const [search, setSearch] = useState('');
    const [selectedOrder, setSelectedOrder] = useState<any>(null);

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

    const getTimeline = (order: any) => {
        const events = [
            { label: 'Order Created', time: order.created_at, icon: Calendar, done: true },
            { label: 'Payment Confirmed', time: order.payment_status === 'PAID' ? order.created_at : null, icon: CheckCircle, done: order.payment_status === 'PAID' },
            { label: 'Driver Assigned', time: order.driver_assigned_at, icon: Truck, done: !!order.driver_assigned_at },
            { label: 'Picked Up', time: order.status === 'IN_TRANSIT' || order.status === 'DELIVERED' ? order.updated_at : null, icon: Package, done: order.status === 'IN_TRANSIT' || order.status === 'DELIVERED' },
            { label: 'Delivered', time: order.delivered_at, icon: CheckCircle, done: !!order.delivered_at },
        ].filter(e => e.time || e.done);
        return events;
    };

    return (
        <div className="fade-in" style={{ display: 'flex', gap: '2rem', height: '100%' }}>
            <div style={{ flex: 1, overflowY: 'auto' }}>
                <div className="page-header">
                    <div className="page-header-left">
                        <h2><Package size={22} style={{ color: 'var(--accent-primary)' }} /> Order Orchestration</h2>
                        <p>Monitor the standard journey of every platform request</p>
                    </div>
                    <button className="btn btn-secondary" onClick={fetchOrders} disabled={loading}>
                        <RefreshCw size={15} className={loading ? 'spin' : ''} />
                        Refresh
                    </button>
                </div>

                <div style={{ display: 'flex', gap: '1rem', alignItems: 'center', marginBottom: '1.25rem' }}>
                    <div className="filter-tabs">
                        {FILTER_TABS.map(f => (
                            <button key={f} className={`filter-tab ${activeFilter === f ? 'active' : ''}`} onClick={() => setActiveFilter(f)}>
                                {f === 'All' ? `All (${orders.length})` : f}
                            </button>
                        ))}
                    </div>
                    <div className="search-bar" style={{ marginLeft: 'auto' }}>
                        <Search size={14} color="var(--text-secondary)" />
                        <input placeholder="Search code..." value={search} onChange={e => setSearch(e.target.value)} />
                    </div>
                </div>

                <div className="table-container">
                    <table className="data-table">
                        <thead>
                            <tr>
                                <th>Order Code</th>
                                <th>Status</th>
                                <th>Value (UGX)</th>
                                <th>Last Pulse</th>
                                <th></th>
                            </tr>
                        </thead>
                        <tbody>
                            {loading ? (
                                <tr><td colSpan={5} style={{ textAlign: 'center', padding: '3rem' }}><RefreshCw className="spin" /></td></tr>
                            ) : filtered.map(order => (
                                <tr
                                    key={order.id}
                                    onClick={() => setSelectedOrder(order)}
                                    style={{ cursor: 'pointer', background: selectedOrder?.id === order.id ? 'rgba(59,130,246,0.05)' : '' }}
                                >
                                    <td className="font-mono" style={{ fontWeight: 700 }}>{order.order_code || '---'}</td>
                                    <td><span className={`badge ${STATUS_BADGE[order.status] ?? 'badge-info'}`}>{order.status}</span></td>
                                    <td style={{ fontWeight: 600 }}>{order.subtotal?.toLocaleString() ?? '—'}</td>
                                    <td style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>{new Date(order.updated_at || order.created_at).toLocaleString()}</td>
                                    <td><ChevronRight size={16} opacity={0.3} /></td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            </div>

            {/* Sidebar Details / Lifecycle */}
            {selectedOrder && (
                <div className="glass-panel" style={{ width: '380px', flexShrink: 0, padding: '1.5rem', overflowY: 'auto' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
                        <h3 className="text-h3">Order Lifecycle</h3>
                        <button className="btn btn-secondary btn-sm" onClick={() => setSelectedOrder(null)}>Close</button>
                    </div>

                    {/* Timeline */}
                    <div style={{ position: 'relative', paddingLeft: '2rem' }}>
                        <div style={{ position: 'absolute', left: '7px', top: '10px', bottom: '10px', width: '2px', background: 'var(--border-subtle)' }} />
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
                            {getTimeline(selectedOrder).map((node, i) => (
                                <div key={i} style={{ position: 'relative' }}>
                                    <div style={{
                                        position: 'absolute', left: '-2.4rem', top: '0',
                                        width: '18px', height: '18px', borderRadius: '50%',
                                        background: node.done ? 'var(--status-success)' : 'var(--bg-surface-elevated)',
                                        border: '3px solid var(--bg-surface)',
                                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                                        zIndex: 2
                                    }}>
                                        {node.done && <CheckCircle size={10} color="white" />}
                                    </div>
                                    <div>
                                        <div style={{ fontSize: '0.9rem', fontWeight: 600 }}>{node.label}</div>
                                        <div style={{ fontSize: '0.72rem', color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', gap: 4 }}>
                                            <Clock size={10} /> {new Date(node.time || '').toLocaleString()}
                                        </div>
                                    </div>
                                </div>
                            ))}
                        </div>
                    </div>

                    <div className="divider" />

                    {/* Metadata */}
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                        <div style={{ display: 'flex', gap: '12px' }}>
                            <Store size={18} color="var(--accent-primary)" />
                            <div>
                                <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', fontWeight: 600 }}>Source Entity</div>
                                <div style={{ fontSize: '0.9rem' }}>Clinic: {selectedOrder.clinic_id?.split('-')[0]}...</div>
                            </div>
                        </div>
                        <div style={{ display: 'flex', gap: '12px' }}>
                            <Building2 size={18} color="var(--status-success)" />
                            <div>
                                <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', fontWeight: 600 }}>Fullfillment Partner</div>
                                <div style={{ fontSize: '0.9rem' }}>Pharmacy: {selectedOrder.pharmacy_id?.split('-')[0]}...</div>
                            </div>
                        </div>
                        <div style={{ display: 'flex', gap: '12px' }}>
                            <MapPin size={18} color="var(--status-warning)" />
                            <div>
                                <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', fontWeight: 600 }}>Delivery Destination</div>
                                <div style={{ fontSize: '0.9rem', lineHeight: 1.4 }}>{selectedOrder.delivery_address || 'Collection Point'}</div>
                            </div>
                        </div>
                    </div>

                    <div style={{ marginTop: '2rem' }}>
                        <button className="btn btn-primary" style={{ width: '100%' }}>
                            <ExternalLink size={16} /> Open Detailed Audit
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
};
