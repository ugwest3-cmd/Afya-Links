import { useState, useEffect, useMemo } from 'react';
import {
    DollarSign, RefreshCw, Search, ShieldAlert,
    CheckCircle2, Lock, TrendingUp, BarChart3,
    PieChart as PieChartIcon, ArrowUpRight
} from 'lucide-react';
import {
    BarChart, Bar, XAxis, YAxis, CartesianGrid,
    Tooltip, ResponsiveContainer, LineChart, Line,
    Cell, PieChart, Pie
} from 'recharts';
import api from '../utils/api';

const STATUS_BADGE: Record<string, string> = {
    AWAITING_PAYMENT: 'badge-warning',
    PAID: 'badge-info',
    COMPLETED: 'badge-success',
    REFUNDED: 'badge-secondary',
    DISPUTE: 'badge-danger',
};

const COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6'];

interface LedgerItem {
    id: string;
    order_code: string;
    status: string;
    created_at: string;
    total_platform_revenue: number;
    pharmacy_net: number;
    driver_net: number;
    total_payable: number;
    clinic?: { name: string };
    pharmacy?: { name: string };
}

interface Metrics {
    totalLocked: number;
    totalReleased: number;
    platformRevenue: number;
}

export const Escrow = () => {
    const [ledger, setLedger] = useState<LedgerItem[]>([]);
    const [metrics, setMetrics] = useState<Metrics | null>(null);
    const [loading, setLoading] = useState(true);
    const [actionLoading, setActionLoading] = useState<string | null>(null);
    const [activeFilter, setActiveFilter] = useState('All');
    const [search, setSearch] = useState('');

    const fetchLedger = async () => {
        try {
            setLoading(true);
            const res = await api.get('/admin/escrow');
            if (res.data.success) {
                setLedger(res.data.ledger);
                setMetrics(res.data.metrics);
            }
        } catch (error) {
            console.error('Failed to fetch escrow ledger:', error);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => { fetchLedger(); }, []);

    // Analytics Processing
    const revenueTrend = useMemo(() => {
        const daily = ledger
            .filter(o => o.status === 'COMPLETED')
            .reduce((acc: any, o) => {
                const date = new Date(o.created_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
                acc[date] = (acc[date] || 0) + (Number(o.total_platform_revenue) || 0);
                return acc;
            }, {});

        return Object.entries(daily).map(([name, value]) => ({ name, revenue: value })).reverse();
    }, [ledger]);

    const partnerSplit = useMemo(() => {
        const pharmTotal = ledger.reduce((sum, o) => sum + (Number(o.pharmacy_net) || 0), 0);
        const driverTotal = ledger.reduce((sum, o) => sum + (Number(o.driver_net) || 0), 0);
        const platformTotal = ledger.reduce((sum, o) => sum + (Number(o.total_platform_revenue) || 0), 0);

        return [
            { name: 'Pharmacies', value: pharmTotal },
            { name: 'Drivers', value: driverTotal },
            { name: 'Platform', value: platformTotal }
        ];
    }, [ledger]);

    const performanceIndex = useMemo(() => {
        const counts: Record<string, { name: string; orders: number; revenue: number }> = {};
        ledger.forEach(o => {
            if (!o.pharmacy?.name) return;
            const name = o.pharmacy.name;
            if (!counts[name]) counts[name] = { name, orders: 0, revenue: 0 };
            counts[name].orders += 1;
            counts[name].revenue += (Number(o.pharmacy_net) || 0);
        });
        return Object.values(counts).sort((a, b) => b.revenue - a.revenue).slice(0, 5);
    }, [ledger]);

    const filtered = useMemo(() => {
        return ledger.filter(o => {
            const statusMatch = activeFilter === 'All' || o.status === activeFilter;
            const searchMatch = !search ||
                o.order_code?.toLowerCase().includes(search.toLowerCase()) ||
                o.id?.includes(search) ||
                o.clinic?.name?.toLowerCase().includes(search.toLowerCase());
            return statusMatch && searchMatch;
        });
    }, [ledger, activeFilter, search]);

    return (
        <div className="fade-in">
            <div className="page-header" style={{ marginBottom: '1.5rem' }}>
                <div className="page-header-left">
                    <h2><DollarSign size={22} style={{ color: 'var(--status-success)' }} /> Financial Insights & Escrow</h2>
                    <p>Comprehensive revenue analytics and platform fund orchestration</p>
                </div>
                <button className="btn btn-secondary" onClick={fetchLedger} disabled={loading}>
                    <RefreshCw size={15} className={loading ? 'spin' : ''} />
                    Sync Ledger
                </button>
            </div>

            {/* Charts Section */}
            <div style={{ display: 'grid', gridTemplateColumns: '1.5fr 1fr', gap: '1.5rem', marginBottom: '2rem' }}>
                <div className="card" style={{ height: '320px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1rem' }}>
                        <h3 className="text-h3" style={{ fontSize: '1rem', display: 'flex', alignItems: 'center', gap: 8 }}>
                            <TrendingUp size={16} color="var(--accent-primary)" /> Platform Revenue Trend
                        </h3>
                        <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>Daily Earnings (UGX)</div>
                    </div>
                    <ResponsiveContainer width="100%" height="90%">
                        <BarChart data={revenueTrend}>
                            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" vertical={false} />
                            <XAxis dataKey="name" stroke="var(--text-tertiary)" fontSize={11} tickLine={false} axisLine={false} />
                            <YAxis stroke="var(--text-tertiary)" fontSize={11} tickLine={false} axisLine={false} tickFormatter={(v: number) => `K${v / 1000}`} />
                            <Tooltip
                                contentStyle={{ background: 'var(--bg-surface-elevated)', border: '1px solid var(--border-color)', borderRadius: '8px' }}
                                itemStyle={{ color: 'var(--accent-primary)', fontSize: '12px' }}
                            />
                            <Bar dataKey="revenue" fill="var(--accent-primary)" radius={[4, 4, 0, 0]} barSize={24} />
                        </BarChart>
                    </ResponsiveContainer>
                </div>

                <div className="card" style={{ height: '320px' }}>
                    <h3 className="text-h3" style={{ fontSize: '1rem', display: 'flex', alignItems: 'center', gap: 8, marginBottom: '1rem' }}>
                        <PieChartIcon size={16} color="var(--status-success)" /> Ecosystem Fund Split
                    </h3>
                    <div style={{ display: 'flex', height: '80%' }}>
                        <ResponsiveContainer width="50%" height="100%">
                            <PieChart>
                                <Pie data={partnerSplit} innerRadius={50} outerRadius={70} paddingAngle={5} dataKey="value">
                                    {partnerSplit.map((entry, index) => <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />)}
                                </Pie>
                                <Tooltip />
                            </PieChart>
                        </ResponsiveContainer>
                        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: '12px' }}>
                            {partnerSplit.map((s, i) => (
                                <div key={s.name} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                                    <div style={{ width: 8, height: 8, borderRadius: '50%', background: COLORS[i % COLORS.length] }} />
                                    <div>
                                        <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>{s.name}</div>
                                        <div style={{ fontSize: '0.9rem', fontWeight: 600 }}>{s.value.toLocaleString()}</div>
                                    </div>
                                </div>
                            ))}
                        </div>
                    </div>
                </div>
            </div>

            {/* Metrics */}
            {metrics && (
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '1rem', marginBottom: '2rem' }}>
                    <div className="stat-card" style={{ padding: '1rem 1.25rem' }}>
                        <div className="stat-card-icon" style={{ background: 'rgba(59,130,246,0.1)', color: 'var(--status-info)' }}>
                            <Lock size={18} />
                        </div>
                        <div className="stat-card-info">
                            <div className="label">Locked Escrow</div>
                            <div className="value" style={{ fontSize: '1.25rem' }}>UGX {metrics.totalLocked.toLocaleString()}</div>
                        </div>
                    </div>
                    <div className="stat-card" style={{ padding: '1rem 1.25rem' }}>
                        <div className="stat-card-icon" style={{ background: 'rgba(16,185,129,0.1)', color: 'var(--status-success)' }}>
                            <CheckCircle2 size={18} />
                        </div>
                        <div className="stat-card-info">
                            <div className="label">Total Released</div>
                            <div className="value" style={{ fontSize: '1.25rem' }}>UGX {metrics.totalReleased.toLocaleString()}</div>
                        </div>
                    </div>
                    <div className="stat-card" style={{ padding: '1rem 1.25rem', borderLeft: '3px solid var(--accent-primary)' }}>
                        <div className="stat-card-info">
                            <div className="label">Platform Net</div>
                            <div className="value" style={{ fontSize: '1.25rem', color: 'var(--accent-primary)' }}>UGX {metrics.platformRevenue.toLocaleString()}</div>
                        </div>
                        <ArrowUpRight size={18} style={{ marginLeft: 'auto', opacity: 0.5 }} />
                    </div>
                </div>
            )}

            {/* Secondary Charts: Performance */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.5fr', gap: '1.5rem', marginBottom: '2rem' }}>
                <div className="card">
                    <h3 className="text-h3" style={{ fontSize: '1.1rem', marginBottom: '1.25rem' }}>Pharmacy Performance Index</h3>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                        {performanceIndex.map((p: any, i) => (
                            <div key={p.name} style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                                <div style={{ width: 24, height: 24, borderRadius: '4px', background: 'var(--bg-surface-elevated)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '0.75rem', fontWeight: 800 }}>{i + 1}</div>
                                <div style={{ flex: 1 }}>
                                    <div style={{ fontSize: '0.9rem', fontWeight: 600 }}>{p.name}</div>
                                    <div style={{ height: '4px', width: '100%', background: 'var(--border-subtle)', borderRadius: '2px', marginTop: '6px' }}>
                                        <div style={{ height: '100%', width: `${Math.min(100, (p.revenue / (performanceIndex[0].revenue || 1)) * 100)}%`, background: 'var(--accent-primary)', borderRadius: '2px' }} />
                                    </div>
                                </div>
                                <div style={{ textAlign: 'right' }}>
                                    <div style={{ fontSize: '0.85rem', fontWeight: 600 }}>{p.orders} Orders</div>
                                    <div style={{ fontSize: '0.7rem', color: 'var(--text-secondary)' }}>UGX {p.revenue.toLocaleString()}</div>
                                </div>
                            </div>
                        ))}
                    </div>
                </div>

                <div className="table-container" style={{ border: 'none' }}>
                    <div style={{ display: 'flex', gap: '1rem', alignItems: 'center', marginBottom: '1rem' }}>
                        <div className="filter-tabs">
                            {FILTER_TABS.map(f => (
                                <button key={f} className={`filter-tab ${activeFilter === f ? 'active' : ''}`} onClick={() => setActiveFilter(f)}>
                                    {f === 'All' ? `All (${ledger.length})` : f}
                                </button>
                            ))}
                        </div>
                        <div className="search-bar" style={{ marginLeft: 'auto' }}>
                            <Search size={14} color="var(--text-secondary)" />
                            <input placeholder="Filter ledger..." value={search} onChange={e => setSearch(e.target.value)} />
                        </div>
                    </div>
                    <table className="data-table">
                        <thead>
                            <tr>
                                <th>Order Code</th>
                                <th>Entities</th>
                                <th>Status</th>
                                <th>Total Payable</th>
                                <th>Rev Breakdown</th>
                            </tr>
                        </thead>
                        <tbody>
                            {loading ? (
                                <tr><td colSpan={5} style={{ textAlign: 'center', padding: '2rem' }}><RefreshCw className="spin" size={20} /></td></tr>
                            ) : filtered.map(item => (
                                <tr key={item.id}>
                                    <td className="font-mono" style={{ fontWeight: 700 }}>{item.order_code || '—'}</td>
                                    <td>
                                        <div style={{ fontSize: '0.85rem', fontWeight: 500 }}>{item.clinic?.name || 'Clinic'}</div>
                                        <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>→ {item.pharmacy?.name || 'Pharmacy'}</div>
                                    </td>
                                    <td><span className={`badge ${STATUS_BADGE[item.status] ?? 'badge-secondary'}`}>{item.status}</span></td>
                                    <td style={{ fontWeight: 600 }}>UGX {Number(item.total_payable || 0).toLocaleString()}</td>
                                    <td>
                                        <div style={{ color: 'var(--status-success)', fontSize: '0.75rem' }}>Ph: {Number(item.pharmacy_net || 0).toLocaleString()}</div>
                                        <div style={{ color: 'var(--accent-primary)', fontSize: '0.75rem' }}>Adm: {Number(item.total_platform_revenue || 0).toLocaleString()}</div>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    );
};
