import { useEffect, useState } from 'react';
import api from '../utils/api';
import {
    CheckCircle, Clock, ShieldCheck, UserCheck,
    FileText, Phone, ExternalLink, ShieldAlert
} from 'lucide-react';

interface User {
    id: string;
    name: string;
    phone: string;
    role: string;
    created_at: string;
    document_url?: string;
}

export const Verifications = () => {
    const [users, setUsers] = useState<User[]>([]);
    const [loading, setLoading] = useState(true);

    const fetchVerifications = async () => {
        try {
            setLoading(true);
            const res = await api.get('/admin/verifications/pending');
            if (res.data.success) {
                setUsers(res.data.pending_users || []);
            }
        } catch (e) {
            console.error(e);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchVerifications();
    }, []);

    const handleApprove = async (id: string, role: string) => {
        try {
            if (window.confirm(`Are you sure you want to activate this ${role} account? This will grant them full access to the platform.`)) {
                await api.post(`/admin/users/${id}/approve`);
                setUsers(users.filter(u => u.id !== id));
            }
        } catch (e) {
            console.error(e);
            alert('Failed to approve user');
        }
    };

    return (
        <div className="fade-in">
            <header className="page-header" style={{ marginBottom: '2.5rem' }}>
                <div className="page-header-left">
                    <h2><ShieldCheck size={22} style={{ color: 'var(--accent-secondary)' }} /> Trust & Verification</h2>
                    <p>Review and authorize new partners joining the AfyaLinks network</p>
                </div>
                <div className="glass-panel" style={{ padding: '0.5rem 1rem', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <ShieldAlert size={16} color="var(--status-warning)" />
                    <span style={{ fontSize: '0.85rem', fontWeight: 600 }}>{users.length} Pending Activations</span>
                </div>
            </header>

            {loading ? (
                <div style={{ textAlign: 'center', padding: '4rem', color: 'var(--text-secondary)' }}>
                    <Clock className="spin" size={32} style={{ marginBottom: '1rem', opacity: 0.5 }} />
                    <p>Fetching KYC submissions...</p>
                </div>
            ) : users.length === 0 ? (
                <div className="empty-state" style={{ background: 'var(--bg-surface)', borderRadius: 'var(--radius-lg)', padding: '6rem 2rem' }}>
                    <div style={{ width: 80, height: 80, borderRadius: '50%', background: 'rgba(16,185,129,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '1.5rem' }}>
                        <UserCheck size={40} color="var(--status-success)" />
                    </div>
                    <h3 className="text-h3">Gatekeeper Status: Clear</h3>
                    <p className="text-muted" style={{ maxWidth: '400px' }}>All pending clinics, pharmacies, and drivers have been verified. No new entities are awaiting activation.</p>
                </div>
            ) : (
                <div className="grid" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(340px, 1fr))', gap: '1.5rem' }}>
                    {users.map(user => (
                        <div key={user.id} className="card fade-in" style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                                <div>
                                    <div style={{ fontSize: '0.65rem', color: 'var(--text-secondary)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '4px' }}>{user.role} Application</div>
                                    <h3 className="text-h3" style={{ fontSize: '1.15rem' }}>{user.name || 'New Provider'}</h3>
                                </div>
                                <span className="badge badge-warning">Awaiting KYC</span>
                            </div>

                            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
                                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
                                    <Phone size={14} /> {user.phone}
                                </div>
                                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
                                    <Clock size={14} /> Registered: {new Date(user.created_at).toLocaleDateString()}
                                </div>
                            </div>

                            <div className="divider" style={{ margin: '0.5rem 0' }} />

                            <div style={{ display: 'flex', gap: '12px' }}>
                                {user.document_url ? (
                                    <a
                                        href={user.document_url}
                                        target="_blank"
                                        rel="noopener noreferrer"
                                        className="btn btn-secondary"
                                        style={{ flex: 1, justifyContent: 'center' }}
                                    >
                                        <FileText size={16} /> View License
                                    </a>
                                ) : (
                                    <div className="btn btn-secondary disabled" style={{ flex: 1, opacity: 0.5, cursor: 'not-allowed', justifyContent: 'center' }}>
                                        No Document
                                    </div>
                                )}
                                <button
                                    onClick={() => handleApprove(user.id, user.role)}
                                    className="btn btn-primary"
                                    style={{ flex: 1, justifyContent: 'center' }}
                                >
                                    <UserCheck size={16} /> Approve
                                </button>
                            </div>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
};
