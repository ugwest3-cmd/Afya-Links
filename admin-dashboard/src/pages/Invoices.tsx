import { useEffect, useState } from 'react';
import api from '../utils/api';
import { FileText, CheckCircle, Clock, AlertCircle, ExternalLink } from 'lucide-react';

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

export const Invoices = () => {
    const [invoices, setInvoices] = useState<Invoice[]>([]);
    const [loading, setLoading] = useState(true);

    const fetchInvoices = async () => {
        try {
            const res = await api.get('/admin/invoices');
            if (res.data.success) {
                setInvoices(res.data.invoices || []);
            }
        } catch (e) {
            console.error(e);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchInvoices();
    }, []);

    const handleVerify = async (id: string) => {
        try {
            if (window.confirm('Mark this invoice as PAID?')) {
                await api.post(`/admin/invoices/${id}/verify`);
                setInvoices(invoices.map(inv =>
                    inv.id === id ? { ...inv, status: 'PAID' } : inv
                ));
            }
        } catch (e) {
            console.error(e);
            alert('Failed to verify payment');
        }
    };

    const getStatusBadge = (status: string) => {
        switch (status) {
            case 'PAID':
                return <span className="badge badge-success"><CheckCircle size={12} /> Paid</span>;
            case 'PENDING_VERIFICATION':
                return <span className="badge badge-warning"><Clock size={12} /> Verifying</span>;
            case 'UNPAID':
                return <span className="badge badge-info">Unpaid</span>;
            case 'OVERDUE':
                return <span className="badge badge-danger"><AlertCircle size={12} /> Overdue</span>;
            default:
                return <span className="badge">{status}</span>;
        }
    };

    return (
        <div className="fade-in" style={{ maxWidth: '1200px', margin: '0 auto' }}>
            <header style={{ marginBottom: '2rem' }}>
                <h1 className="text-h2">Transactions & Invoices</h1>
                <p className="text-muted">Manage pharmacy commissions and platform service fees.</p>
            </header>

            {loading ? (
                <div style={{ textAlign: 'center', padding: '3rem', color: 'var(--text-secondary)' }}>Loading invoices...</div>
            ) : invoices.length === 0 ? (
                <div className="glass-panel" style={{ textAlign: 'center', padding: '4rem 2rem' }}>
                    <FileText size={48} style={{ color: 'var(--accent-primary)', margin: '0 auto 1rem', opacity: 0.5 }} />
                    <h3 className="text-h3">No invoices generated</h3>
                    <p className="text-muted" style={{ marginTop: '0.5rem' }}>Weekly invoices will appear here automatically.</p>
                </div>
            ) : (
                <div className="glass-panel" style={{ overflow: 'hidden' }}>
                    <table className="data-table">
                        <thead>
                            <tr>
                                <th>Billing Period</th>
                                <th>Amount (UGX)</th>
                                <th>Status</th>
                                <th>Proof</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {invoices.map(invoice => (
                                <tr key={invoice.id}>
                                    <td>
                                        <div style={{ fontSize: '0.9rem', fontWeight: 500 }}>
                                            {new Date(invoice.period_start).toLocaleDateString()} - {new Date(invoice.period_end).toLocaleDateString()}
                                        </div>
                                        <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
                                            Generated: {new Date(invoice.created_at).toLocaleDateString()}
                                        </div>
                                    </td>
                                    <td style={{ fontWeight: 600, color: 'var(--text-primary)' }}>
                                        {invoice.total_amount.toLocaleString()}
                                    </td>
                                    <td>{getStatusBadge(invoice.status)}</td>
                                    <td>
                                        {invoice.payment_proof_url ? (
                                            <a
                                                href={invoice.payment_proof_url}
                                                target="_blank"
                                                rel="noopener noreferrer"
                                                className="btn-secondary"
                                                style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem', display: 'flex', alignItems: 'center', gap: '4px', width: 'fit-content' }}
                                            >
                                                <ExternalLink size={12} /> View Proof
                                            </a>
                                        ) : (
                                            <span style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>None</span>
                                        )}
                                    </td>
                                    <td>
                                        {invoice.status !== 'PAID' && (
                                            <button
                                                onClick={() => handleVerify(invoice.id)}
                                                className="btn-secondary"
                                                style={{ color: 'var(--status-success)', borderColor: 'rgba(16, 185, 129, 0.3)' }}
                                            >
                                                Confirm Payment
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
