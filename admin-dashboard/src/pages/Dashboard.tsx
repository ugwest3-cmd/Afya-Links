import { useEffect, useState } from 'react';
import {
    Package, Users, ShieldAlert, TrendingUp, RefreshCw,
    Activity, DollarSign, Zap, Globe, Server, ShieldCheck,
    BaggageClaim, Truck
} from 'lucide-react';
import api from '../utils/api';

interface Stats {
    totalUsers: number;
    clinics: number;
    pharmacies: number;
    drivers: number;
    totalOrders: number;
    pendingVerifications: number;
    platformRevenue: number;
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
        clinics: 0,
        pharmacies: 0,
        drivers: 0,
        totalOrders: 0,
        pendingVerifications: 0,
        platformRevenue: 0,
        recentOrders: [],
    });
    const [loading, setLoading] = useState(true);

    const fetchStats = async () => {
        try {
            setLoading(true);
            const [usersRes, ordersRes, verificationsRes] = await Promise.all([
                api.get('/admin/users'),
                api.get('/admin/orders'),
                api.get('/admin/verifications/pending'),
            ]);

            const allUsers = usersRes.data.users ?? [];
            const allOrders = ordersRes.data.orders ?? [];

            setStats({
                totalUsers: allUsers.length,
                clinics: allUsers.filter((u: any) => u.role === 'CLINIC').length,
                pharmacies: allUsers.filter((u: any) => u.role === 'PHARMACY').length,
                drivers: allUsers.filter((u: any) => u.role === 'DRIVER').length,
                totalOrders: allOrders.length,
                pendingVerifications: verificationsRes.data.pending_users?.length ?? 0,
                platformRevenue: allOrders
                    .filter((o: any) => o.status === 'COMPLETED' || o.status === 'DELIVERED')
                    .reduce((sum: number, o: any) => sum + (Number(o.total_platform_revenue) || 0), 0),
                recentOrders: allOrders.slice(0, 5),
            });
        } catch (e) {
            console.error('Dashboard fetch error:', e);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => { fetchStats(); }, []);

    const healthIndicators = [
        { label: 'API Gateway', status: 'Healthy', icon: Server, color: 'var(--status-success)' },
        { label: 'Payments (PESAPAL)', status: 'Active', icon: Globe, color: 'var(--status-success)' },
        { label: 'Cloud Messaging', status: 'Operational', icon: Zap, color: 'var(--status-success)' },
        { label: 'Security (Audit)', status: 'Verified', icon: ShieldCheck, color: 'var(--accent-secondary)' },
    ];

    const statCards = [
        {
            label: 'Total Orders',
            value: stats.totalOrders,
            icon: Package,
            gradient: 'var(--grad-primary)',
            bg: 'rgba(59,130,246,0.1)',
        },
        {
            label: 'Platform Revenue',
            value: `UGX ${stats.platformRevenue.toLocaleString()}`,
            icon: DollarSign,
            gradient: 'var(--grad-green)',
            bg: 'rgba(16,185,129,0.1)',
        },
        {
            label: 'Active Clinics',
            value: stats.clinics,
            icon: BaggageClaim,
            gradient: 'linear-gradient(135deg, #ec4899, #d946ef)',
            bg: 'rgba(236,72,153,0.1)',
        },
        {
            label: 'Ready Drivers',
            value: stats.drivers,
            icon: Truck,
            gradient: 'var(--grad-orange)',
            bg: 'rgba(245,158,11,0.1)',
        },
    ];

    return (
        <div className="fade-in">
            {/* Header */}
            <div className="page-header" style={{ marginBottom: '1.5rem' }}>
                <div className="page-header-left">
                    <h2><Activity size={22} style={{ color: 'var(--accent-primary)' }} /> Live Platform Performance</h2>
                    <p>Orchestrating the health of your AfyaLinks network</p>
                </div>
                <button className="btn btn-secondary" onClick={fetchStats} disabled={loading}>
                    <RefreshCw size={15} className={loading ? 'spin' : ''} />
                    Sync Data
                </button>
            </div>

            {/* Health Indicators */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem', marginBottom: '2rem' }}>
                {healthIndicators.map((h) => (
                    <div key={h.label} className="glass-panel" style={{ padding: '0.75rem 1rem', display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <div style={{ color: h.color }}>
                            <h.icon size={18} />
                        </div>
                        <div>
                            <div style={{ fontSize: '0.65rem', color: 'var(--text-secondary)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>{h.label}</div>
                            <div style={{ fontSize: '0.85rem', fontWeight: 700, display: 'flex', alignItems: 'center', gap: '4px' }}>
                                <div style={{ width: 6, height: 6, borderRadius: '50%', background: h.color }} />
                                {h.status}
                            </div>
                        </div>
                    </div>
                ))}
            </div>

            {/* Stat Cards */}
            <div className="stats-grid">
                {statCards.map((s) => (
                    <div className="stat-card" key={s.label}>
                        <div className="stat-card-icon" style={{ background: s.bg }}>
                            <s.icon size={22} style={{ color: 'var(--text-primary)' }} />
                        </div>
                        <div>
                            <div className="label">{s.label}</div>
                            <div className="value">{loading ? '—' : s.value}</div>
                            <div className="trend" style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                                <TrendingUp size={11} color="var(--status-success)" />
                                Real-time metric
                            </div>
                        </div>
                        <div style={{ position: 'absolute', bottom: 0, left: 0, width: '100%', height: '3px', background: s.gradient }} />
                    </div>
                ))}
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1.5fr 1fr', gap: '2rem' }}>
                {/* Recent Orders */}
                <div>
                    <div style={{ marginBottom: '1rem', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                        <h3 className="text-h3">Global Activity Log</h3>
                        <a href="/orders" style={{ fontSize: '0.82rem', color: 'var(--accent-primary)' }}>Full Ledger →</a>
                    </div>

                    <div className="table-container">
                        <table className="data-table">
                            <thead>
                                <tr>
                                    <th>Order</th>
                                    <th>Carrier</th>
                                    <th>Status</th>
                                    <th>Value (UGX)</th>
                                </tr>
                            </thead>
                            <tbody>
                                {loading ? (
                                    <tr><td colSpan={4} style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-secondary)' }}>Syncing records...</td></tr>
                                ) : stats.recentOrders.length === 0 ? (
                                    <tr><td colSpan={4} className="empty-state">No platform activity noted.</td></tr>
                                ) : stats.recentOrders.map(order => (
                                    <tr key={order.id}>
                                        <td className="font-mono" style={{ fontWeight: 700 }}>{order.order_code || '---'}</td>
                                        <td style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>{order.driver_id ? 'Assigned' : 'Peding Dispatch'}</td>
                                        <td><span className={`badge ${STATUS_BADGE[order.status] ?? 'badge-info'}`}>{order.status}</span></td>
                                        <td style={{ fontWeight: 600 }}>{order.subtotal?.toLocaleString() ?? '—'}</td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </div>

                {/* Quick Actions / Summary */}
                <div>
                    <h3 className="text-h3" style={{ marginBottom: '1rem' }}>Platform Pulse</h3>
                    <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', paddingBottom: '1rem', borderBottom: '1px solid var(--border-subtle)' }}>
                            <div style={{ width: 44, height: 44, borderRadius: '50%', background: 'rgba(245,158,11,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--status-warning)' }}>
                                <ShieldAlert size={20} style={{ margin: '0 auto' }} />
                            </div>
                            <div>
                                <div style={{ fontSize: '1rem', fontWeight: 700 }}>{stats.pendingVerifications} Pending KYC</div>
                                <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>Verification requests requiring attention</div>
                            </div>
                            <a href="/verifications" style={{ marginLeft: 'auto', fontSize: '1.2rem', color: 'var(--accent-primary)' }}>➔</a>
                        </div>

                        <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                            <div style={{ width: 44, height: 44, borderRadius: '50%', background: 'rgba(16,185,129,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--status-success)' }}>
                                <Zap size={20} style={{ margin: '0 auto' }} />
                            </div>
                            <div>
                                <div style={{ fontSize: '1rem', fontWeight: 700 }}>{stats.pharmacies} Registered Pharmacies</div>
                                <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>Supplying meds across the platform</div>
                            </div>
                        </div>

                        <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                            <div style={{ width: 44, height: 44, borderRadius: '50%', background: 'rgba(59,130,246,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--status-info)' }}>
                                <Users size={20} style={{ margin: '0 auto' }} />
                            </div>
                            <div>
                                <div style={{ fontSize: '1rem', fontWeight: 700 }}>{stats.clinics} Active Clinics</div>
                                <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>Sourcing medication for patients</div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
};
