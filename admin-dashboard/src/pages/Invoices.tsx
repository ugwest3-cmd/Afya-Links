import { useEffect, useState, useMemo } from 'react';
import type { JSX } from 'react';
import api from '../utils/api';
import { FileText, CheckCircle, Clock, AlertCircle, ExternalLink, RefreshCw } from 'lucide-react';

interface Invoice {
    id: string;
    pharmacy_id: string;
    total_amount: number;
    period_start: string;
    period_end: string;
    status: 'UNPAID' | 'PENDING_VERIFICATION' | 'PAID' | 'OVERDUE';
    payment_proof_url: string | null;
    created_at: string;
}

const STATUS_BADGE: Record<string, JSX.Element> = {
    PAID: <span className="badge badge-success"><CheckCircle size={11} /> Paid</span>,
    PENDING_VERIFICATION: <span className="badge badge-warning"><Clock size={11} /> Verifying</span>,
    UNPAID: <span className="badge badge-info">Unpaid</span>,
    OVERDUE: <span className="badge badge-danger"><AlertCircle size={11} /> Overdue</span>,
};

const FILTER_TABS = ['All', 'UNPAID', 'PENDING_VERIFICATION', 'PAID', 'OVERDUE'];

export const Invoices = () => {
    const [invoices, setInvoices] = useState<Invoice[]>([]);
    const [loading, setLoading] = useState(true);
    const [activeFilter, setActiveFilter] = useState('All');
    const [verifying, setVerifying] = useState<string | null>(null);

    const fetchInvoices = async () => {
        try {
            setLoading(true);
            const res = await api.get('/admin/invoices');
            if (res.data.success) setInvoices(res.data.invoices || []);
        } catch (e) {
            console.error(e);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => { fetchInvoices(); }, []);

    const handleVerify = async (id: string) => {
        if (!window.confirm('Mark this invoice as PAID?')) return;
        try {
            setVerifying(id);
            await api.post(`/admin/invoices/${id}/verify`);
            setInvoices(prev => prev.map(inv => inv.id === id ? { ...inv, status: 'PAID' } : inv));
        } catch (e) {
            alert('Failed to verify payment');
        } finally {
            setVerifying(null);
        }
    };

    const filtered = useMemo(() =>
        activeFilter === 'All' ? invoices : invoices.filter(i => i.status === activeFilter),
        [invoices, activeFilter]
    );

    const totalPaid = invoices.filter(i => i.status === 'PAID').reduce((s, i) => s + i.total_amount, 0);
    const totalPending = invoices.filter(i => i.status !== 'PAID').reduce((s, i) => s + i.total_amount, 0);

    return (
        <div className="fade-in">
            <div className="page-header">
                <div className="page-header-left">
                    <h2><FileText size={22} style={{ color: 'var(--accent-primary)' }} /> Invoices</h2>
                    <p>Manage pharmacy commissions and platform service fees</p>
                </div>
                <button className="btn btn-secondary" onClick={fetchInvoices} disabled={loading}>
                    <RefreshCw size={15} className={loading ? 'spin' : ''} />
                    Refresh
                </button>
            </div>

            {/* Summary Cards */}
            <div className="stats-grid" style={{ gridTemplateColumns: 'repeat(3, 1fr)', marginBottom: '1.5rem' }}>
                <div className="stat-card">
                    <div className="stat-card-icon" style={{ background: 'rgba(59,130,246,0.1)' }}>
                        <FileText size={20} color="var(--accent-primary)" />
                    </div>
                    <div>
                        <div className="label">Total Invoices</div>
                        <div className="value">{invoices.length}</div>
                    </div>
                </div>
                <div className="stat-card">
                    <div className="stat-card-icon" style={{ background: 'rgba(16,185,129,0.1)' }}>
                        <CheckCircle size={20} color="var(--status-success)" />
                    </div>
                    <div>
                        <div className="label">Total Paid</div>
                        <div className="value" style={{ fontSize: '1.3rem' }}>UGX {totalPaid.toLocaleString()}</div>
                    </div>
                </div>
                <div className="stat-card">
                    <div className="stat-card-icon" style={{ background: 'rgba(245,158,11,0.1)' }}>
                        <Clock size={20} color="var(--status-warning)" />
                    </div>
                    <div>
                        <div className="label">Outstanding</div>
                        <div className="value" style={{ fontSize: '1.3rem' }}>UGX {totalPending.toLocaleString()}</div>
                    </div>
                </div>
            </div>

            {/* Filter Tabs */}
            <div style={{ display: 'flex', gap: '1rem', marginBottom: '1rem', alignItems: 'center' }}>
                <div className="filter-tabs">
                    {FILTER_TABS.map(f => (
                        <button key={f} className={`filter-tab ${activeFilter === f ? 'active' : ''}`} onClick={() => setActiveFilter(f)}>
                            {f === 'PENDING_VERIFICATION' ? 'Verifying' : f}
                        </button>
                    ))}
                </div>
            </div>

            {loading ? (
                <div style={{ textAlign: 'center', padding: '3rem' }}>
                    <RefreshCw className="spin" size={24} style={{ margin: '0 auto', display: 'block', color: 'var(--text-secondary)' }} />
                </div>
            ) : filtered.length === 0 ? (
                <div className="table-container">
                    <div className="empty-state">
                        <FileText size={42} />
                        <p>No invoices found{activeFilter !== 'All' ? ` with status "${activeFilter}"` : ''}.</p>
                    </div>
                </div>
            ) : (
                <div className="table-container">
                    <table className="data-table">
                        <thead>
                            <tr>
                                <th>Billing Period</th>
                                <th>Amount (UGX)</th>
                                <th>Status</th>
                                <th>Payment Proof</th>
                                <th>Generated</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {filtered.map(invoice => (
                                <tr key={invoice.id}>
                                    <td>
                                        <div style={{ fontWeight: 500 }}>
                                            {new Date(invoice.period_start).toLocaleDateString()} – {new Date(invoice.period_end).toLocaleDateString()}
                                        </div>
                                    </td>
                                    <td style={{ fontWeight: 700, fontSize: '1rem' }}>{invoice.total_amount.toLocaleString()}</td>
                                    <td>{STATUS_BADGE[invoice.status] ?? <span className="badge">{invoice.status}</span>}</td>
                                    <td>
                                        {invoice.payment_proof_url ? (
                                            <a href={invoice.payment_proof_url} target="_blank" rel="noopener noreferrer" className="btn btn-sm btn-secondary">
                                                <ExternalLink size={12} /> View Proof
                                            </a>
                                        ) : (
                                            <span style={{ color: 'var(--text-secondary)', fontSize: '0.82rem' }}>Not uploaded</span>
                                        )}
                                    </td>
                                    <td style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
                                        {new Date(invoice.created_at).toLocaleDateString()}
                                    </td>
                                    <td>
                                        {invoice.status !== 'PAID' && (
                                            <button
                                                className="btn btn-sm btn-success"
                                                onClick={() => handleVerify(invoice.id)}
                                                disabled={verifying === invoice.id}
                                            >
                                                {verifying === invoice.id ? <RefreshCw size={12} className="spin" /> : <CheckCircle size={12} />}
                                                Mark Paid
                                            </button>
                                        )}
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            )}
        </div>
    );
};
