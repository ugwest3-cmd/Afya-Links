import { useEffect, useState } from 'react';
import { Package, Users, ShieldAlert, FileText, TrendingUp, RefreshCw, Activity } from 'lucide-react';
import api from '../utils/api';

interface Stats {
    totalUsers: number;
    totalOrders: number;
    pendingVerifications: number;
    totalInvoices: number;
    recentOrders: any[];
}

const STATUS_BADGE: Record<string, string> = {
    PENDING: 'badge-warning',
    ASSIGNED: 'badge-info',
    DELIVERED: 'badge-success',
    REJECTED: 'badge-danger',
};

export const Dashboard = () => {
    const [stats, setStats] = useState<Stats>({
        totalUsers: 0,
        totalOrders: 0,
        pendingVerifications: 0,
        totalInvoices: 0,
        recentOrders: [],
    });
    const [loading, setLoading] = useState(true);

    const fetchStats = async () => {
        try {
            setLoading(true);
            const [usersRes, ordersRes, verificationsRes, invoicesRes] = await Promise.all([
                api.get('/admin/users'),
                api.get('/admin/orders'),
                api.get('/admin/verifications/pending'),
                api.get('/admin/invoices'),
            ]);

            setStats({
                totalUsers: usersRes.data.users?.length ?? 0,
                totalOrders: ordersRes.data.orders?.length ?? 0,
                pendingVerifications: verificationsRes.data.pending_users?.length ?? 0,
                totalInvoices: invoicesRes.data.invoices?.length ?? 0,
                recentOrders: (ordersRes.data.orders ?? []).slice(0, 5),
            });
        } catch (e) {
            console.error('Dashboard fetch error:', e);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => { fetchStats(); }, []);

    const statCards = [
        {
            label: 'Total Users',
            value: stats.totalUsers,
            icon: Users,
            gradient: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
            bg: 'rgba(59,130,246,0.1)',
        },
        {
            label: 'Total Orders',
            value: stats.totalOrders,
            icon: Package,
            gradient: 'linear-gradient(135deg, #10b981, #059669)',
            bg: 'rgba(16,185,129,0.1)',
        },
        {
            label: 'Pending KYC',
            value: stats.pendingVerifications,
            icon: ShieldAlert,
            gradient: 'linear-gradient(135deg, #f59e0b, #d97706)',
            bg: 'rgba(245,158,11,0.1)',
        },
        {
            label: 'Total Invoices',
            value: stats.totalInvoices,
            icon: FileText,
            gradient: 'linear-gradient(135deg, #8b5cf6, #7c3aed)',
            bg: 'rgba(139,92,246,0.1)',
        },
    ];

    return (
        <div className="fade-in">
            {/* Header */}
            <div className="page-header">
                <div className="page-header-left">
                    <h2><Activity size={22} style={{ color: 'var(--accent-primary)' }} /> Platform Overview</h2>
                    <p>Live metrics across your AfyaLinks network</p>
                </div>
                <button className="btn btn-secondary" onClick={fetchStats} disabled={loading}>
                    <RefreshCw size={15} className={loading ? 'spin' : ''} />
                    Refresh
                </button>
            </div>

            {/* Stat Cards */}
            <div className="stats-grid">
                {statCards.map((s) => (
                    <div className="stat-card" key={s.label}>
                        <div className="stat-card-icon" style={{ background: s.bg }}>
                            <s.icon size={22} style={{ background: s.gradient, WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent', filter: 'none' }} color="transparent" />
                        </div>
                        <div>
                            <div className="label">{s.label}</div>
                            <div className="value">{loading ? '—' : s.value}</div>
                            <div className="trend" style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                                <TrendingUp size={11} color="var(--status-success)" />
                                Active on platform
                            </div>
                        </div>
                    </div>
                ))}
            </div>

            {/* Recent Orders */}
            <div style={{ marginBottom: '1rem', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <h3 style={{ fontSize: '1rem', fontWeight: 600 }}>Recent Orders</h3>
                <a href="/orders" style={{ fontSize: '0.82rem', color: 'var(--accent-primary)' }}>View all →</a>
            </div>

            <div className="table-container">
                <table className="data-table">
                    <thead>
                        <tr>
                            <th>Order ID</th>
                            <th>Code</th>
                            <th>Status</th>
                            <th>Value (UGX)</th>
                            <th>Date</th>
                        </tr>
                    </thead>
                    <tbody>
                        {loading ? (
                            <tr><td colSpan={5} style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-secondary)' }}>Loading...</td></tr>
                        ) : stats.recentOrders.length === 0 ? (
                            <tr><td colSpan={5} className="empty-state">No orders yet.</td></tr>
                        ) : stats.recentOrders.map(order => (
                            <tr key={order.id}>
                                <td className="font-mono" style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>{order.id.split('-')[0]}…</td>
                                <td className="font-mono" style={{ fontWeight: 600 }}>{order.order_code || '—'}</td>
                                <td><span className={`badge ${STATUS_BADGE[order.status] ?? 'badge-info'}`}>{order.status}</span></td>
                                <td style={{ fontWeight: 500 }}>{order.subtotal?.toLocaleString() ?? '—'}</td>
                                <td style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>{new Date(order.created_at).toLocaleDateString()}</td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>
        </div>
    );
};
