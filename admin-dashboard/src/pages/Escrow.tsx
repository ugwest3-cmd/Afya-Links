import { useState, useEffect, useMemo } from 'react';
import { DollarSign, RefreshCw, Search, ShieldAlert, CheckCircle2, Lock } from 'lucide-react';
import api from '../utils/api';

const ESCROW_BADGE: Record<string, string> = {
    NOT_FUNDED: 'badge-warning',
    LOCKED: 'badge-info',
    RELEASED: 'badge-success',
    RETURNED: 'badge-secondary',
};

const FILTER_TABS = ['All', 'LOCKED', 'RELEASED', 'NOT_FUNDED', 'RETURNED'];

export const Escrow = () => {
    const [ledger, setLedger] = useState<any[]>([]);
    const [metrics, setMetrics] = useState<any>(null);
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

    const handleResolveOptions = async (orderId: string, action: string) => {
        if (!confirm(`Are you sure you want to ${action.replace(/_/g, ' ')}?`)) return;

        try {
            setActionLoading(orderId);
            const res = await api.post('/admin/escrow/resolve', {
                order_id: orderId,
                resolution_action: action
            });
            if (res.data.success) {
                fetchLedger();
            }
        } catch (error) {
            console.error('Failed to resolve dispute:', error);
            alert('Failed to resolve dispute');
        } finally {
            setActionLoading(null);
        }
    };

    const filtered = useMemo(() => {
        return ledger.filter(o => {
            const statusMatch = activeFilter === 'All' || o.escrow_status === activeFilter;
            const searchMatch = !search || o.order_code?.toLowerCase().includes(search.toLowerCase()) || o.id?.includes(search) || o.clinic?.name?.toLowerCase().includes(search.toLowerCase());
            return statusMatch && searchMatch;
        });
    }, [ledger, activeFilter, search]);

    return (
        <div className="fade-in">
            <div className="page-header" style={{ marginBottom: '1.5rem' }}>
                <div className="page-header-left">
                    <h2><DollarSign size={22} style={{ color: 'var(--status-success)' }} /> Escrow Ledger</h2>
                    <p>Track locked funds, platform revenue, and resolve disputes</p>
                </div>
                <button className="btn btn-secondary" onClick={fetchLedger} disabled={loading}>
                    <RefreshCw size={15} className={loading ? 'spin' : ''} />
                    Refresh
                </button>
            </div>

            {/* Metrics */}
            {metrics && (
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '1rem', marginBottom: '2rem' }}>
                    <div className="dashboard-card stat-card">
                        <div className="stat-card-icon" style={{ backgroundColor: 'var(--status-info-bg)', color: 'var(--status-info)' }}>
                            <Lock size={20} />
                        </div>
                        <div className="stat-card-info">
                            <h3>Locked In Escrow</h3>
                            <div className="value">UGX {metrics.totalLocked.toLocaleString()}</div>
                        </div>
                    </div>
                    <div className="dashboard-card stat-card">
                        <div className="stat-card-icon" style={{ backgroundColor: 'var(--status-success-bg)', color: 'var(--status-success)' }}>
                            <CheckCircle2 size={20} />
                        </div>
                        <div className="stat-card-info">
                            <h3>Total Released</h3>
                            <div className="value">UGX {metrics.totalReleased.toLocaleString()}</div>
                        </div>
                    </div>
                    <div className="dashboard-card stat-card border-accent">
                        <div className="stat-card-icon" style={{ backgroundColor: 'var(--accent-bg)', color: 'var(--accent-primary)' }}>
                            <DollarSign size={20} />
                        </div>
                        <div className="stat-card-info">
                            <h3>Platform Revenue</h3>
                            <div className="value" style={{ color: 'var(--accent-primary)' }}>UGX {metrics.platformRevenue.toLocaleString()}</div>
                        </div>
                    </div>
                    <div className="dashboard-card stat-card">
                        <div className="stat-card-icon" style={{ backgroundColor: 'var(--status-danger-bg)', color: 'var(--status-danger)' }}>
                            <ShieldAlert size={20} />
                        </div>
                        <div className="stat-card-info">
                            <h3>Active Disputes</h3>
                            <div className="value" style={{ color: metrics.activeDisputes > 0 ? 'var(--status-danger)' : 'var(--text-primary)' }}>{metrics.activeDisputes}</div>
                        </div>
                    </div>
                </div>
            )}

            {/* Controls */}
            <div style={{ display: 'flex', gap: '1rem', alignItems: 'center', marginBottom: '1.25rem', flexWrap: 'wrap' }}>
                <div className="filter-tabs">
                    {FILTER_TABS.map(f => (
                        <button key={f} className={`filter-tab ${activeFilter === f ? 'active' : ''}`} onClick={() => setActiveFilter(f)}>
                            {f === 'All' ? `All (${ledger.length})` : f}
                        </button>
                    ))}
                </div>
                <div className="search-bar" style={{ marginLeft: 'auto' }}>
                    <Search size={14} color="var(--text-secondary)" />
                    <input
                        placeholder="Search order code or clinic..."
                        value={search}
                        onChange={e => setSearch(e.target.value)}
                    />
                </div>
            </div>

            <div className="table-container">
                <table className="data-table">
                    <thead>
                        <tr>
                            <th>Order Code</th>
                            <th>Clinic / Pharmacy</th>
                            <th>Escrow / Order Status</th>
                            <th>Total Locked</th>
                            <th>Pharmacy Net / Driver Net</th>
                            <th>Actions (Disputes)</th>
                        </tr>
                    </thead>
                    <tbody>
                        {loading ? (
                            <tr><td colSpan={6} style={{ textAlign: 'center', padding: '3rem', color: 'var(--text-secondary)' }}><RefreshCw className="spin" size={20} style={{ margin: '0 auto', display: 'block' }} /></td></tr>
                        ) : filtered.length === 0 ? (
                            <tr>
                                <td colSpan={6}>
                                    <div className="empty-state">
                                        <DollarSign size={42} />
                                        <p>No ledger entries found{activeFilter !== 'All' ? ` with status "${activeFilter}"` : ''}.</p>
                                    </div>
                                </td>
                            </tr>
                        ) : filtered.map(item => (
                            <tr key={item.id}>
                                <td className="font-mono" style={{ fontWeight: 700, fontSize: '0.95rem' }}>{item.order_code || '—'}</td>
                                <td>
                                    <div style={{ fontWeight: 500, fontSize: '0.9rem' }}>{item.clinic?.name || 'Unknown Clinic'}</div>
                                    <div style={{ color: 'var(--text-secondary)', fontSize: '0.75rem' }}>→ {item.pharmacy?.name || 'Unknown Pharmacy'}</div>
                                </td>
                                <td>
                                    <div style={{ display: 'flex', flexDirection: 'column', gap: 4, alignItems: 'flex-start' }}>
                                        <span className={`badge ${ESCROW_BADGE[item.escrow_status] ?? 'badge-secondary'}`}>{item.escrow_status}</span>
                                        <span style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', fontWeight: 600 }}>{item.status}</span>
                                    </div>
                                </td>
                                <td style={{ fontWeight: 600 }}>UGX {Number(item.total_payable || 0).toLocaleString()}</td>
                                <td>
                                    <div style={{ color: 'var(--status-success)', fontSize: '0.85rem', fontWeight: 500 }}>UGX {Number(item.pharmacy_net || 0).toLocaleString()}</div>
                                    <div style={{ color: 'var(--status-info)', fontSize: '0.75rem' }}>UGX {Number(item.driver_net || 0).toLocaleString()}</div>
                                </td>
                                <td>
                                    {item.status === 'DISPUTE' && item.escrow_status === 'LOCKED' ? (
                                        <div style={{ display: 'flex', gap: 6 }}>
                                            <button
                                                className="btn btn-primary"
                                                style={{ padding: '4px 10px', fontSize: '0.75rem', backgroundColor: 'var(--status-success)', borderColor: 'var(--status-success)' }}
                                                onClick={() => handleResolveOptions(item.id, 'RELEASE_TO_PHARMACY')}
                                                disabled={actionLoading === item.id}
                                            >
                                                Force Release
                                            </button>
                                            <button
                                                className="btn btn-secondary"
                                                style={{ padding: '4px 10px', fontSize: '0.75rem' }}
                                                onClick={() => handleResolveOptions(item.id, 'REFUND_TO_CLINIC')}
                                                disabled={actionLoading === item.id}
                                            >
                                                Refund
                                            </button>
                                        </div>
                                    ) : (
                                        <span style={{ color: 'var(--text-secondary)', fontSize: '0.8rem' }}>—</span>
                                    )}
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>
        </div>
    );
};
