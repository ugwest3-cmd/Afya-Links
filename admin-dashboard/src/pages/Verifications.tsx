import { useEffect, useState } from 'react';
import api from '../utils/api';
import { CheckCircle, Clock } from 'lucide-react';

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
            if (window.confirm(`Approve this ${role} account?`)) {
                await api.post(`/admin/users/${id}/approve`);
                setUsers(users.filter(u => u.id !== id));
            }
        } catch (e) {
            console.error(e);
            alert('Failed to approve user');
        }
    };

    return (
        <div className="fade-in" style={{ maxWidth: '1000px', margin: '0 auto' }}>
            <header style={{ marginBottom: '2rem' }}>
                <h1 className="text-h2">Pending Verifications</h1>
                <p className="text-muted">Review and approve new clinics, pharmacies, and drivers.</p>
            </header>

            {loading ? (
                <div style={{ textAlign: 'center', padding: '3rem', color: 'var(--text-secondary)' }}>Loading pending profiles...</div>
            ) : users.length === 0 ? (
                <div className="glass-panel" style={{ textAlign: 'center', padding: '4rem 2rem' }}>
                    <CheckCircle size={48} style={{ color: 'var(--status-success)', margin: '0 auto 1rem', opacity: 0.8 }} />
                    <h3 className="text-h3">All caught up!</h3>
                    <p className="text-muted" style={{ marginTop: '0.5rem' }}>There are no pending actions in the queue.</p>
                </div>
            ) : (
                <div className="glass-panel" style={{ overflow: 'hidden' }}>
                    <table className="data-table">
                        <thead>
                            <tr>
                                <th>Registration Date</th>
                                <th>Phone Number</th>
                                <th>Role Identity</th>
                                <th>Document</th>
                                <th>Status</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {users.map(user => (
                                <tr key={user.id}>
                                    <td>{new Date(user.created_at).toLocaleDateString()}</td>
                                    <td style={{ fontWeight: 500 }}>{user.phone}</td>
                                    <td>
                                        <span className="badge badge-info">{user.role}</span>
                                    </td>
                                    <td>
                                        {user.document_url ? (
                                            <a
                                                href={user.document_url}
                                                target="_blank"
                                                rel="noopener noreferrer"
                                                className="btn-secondary"
                                                style={{ fontSize: '0.8rem', padding: '4px 8px', textDecoration: 'none' }}
                                            >
                                                View Document
                                            </a>
                                        ) : (
                                            <span className="text-muted" style={{ fontSize: '0.85rem' }}>No document</span>
                                        )}
                                    </td>
                                    <td>
                                        <span className="badge badge-warning" style={{ display: 'flex', gap: '4px' }}>
                                            <Clock size={14} /> Pending KYC
                                        </span>
                                    </td>
                                    <td>
                                        <button
                                            onClick={() => handleApprove(user.id, user.role)}
                                            className="btn-secondary"
                                            style={{ color: 'var(--status-success)', borderColor: 'rgba(16, 185, 129, 0.3)' }}
                                        >
                                            Approve Activation
                                        </button>
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
