import { useState, useEffect } from 'react';
import { Bell, Send, RefreshCw, Users, Clock } from 'lucide-react';
import api from '../utils/api';

interface NotifRecord {
    id: string;
    title: string;
    message: string;
    is_read: boolean;
    created_at: string;
}

const AUDIENCE_LABELS: Record<string, string> = {
    ALL: 'All Users',
    CLINIC: 'Clinics',
    PHARMACY: 'Pharmacies',
    DRIVER: 'Drivers',
};

export const Notifications = () => {
    const [message, setMessage] = useState('');
    const [targetRole, setTargetRole] = useState('ALL');
    const [loading, setLoading] = useState(false);
    const [status, setStatus] = useState<{ type: 'success' | 'error'; text: string } | null>(null);
    const [history, setHistory] = useState<NotifRecord[]>([]);
    const [histLoading, setHistLoading] = useState(true);

    const fetchHistory = async () => {
        try {
            setHistLoading(true);
            const res = await api.get('/users/notifications');
            if (res.data.success) setHistory(res.data.notifications ?? []);
        } catch (e) { /* silent */ }
        finally { setHistLoading(false); }
    };

    useEffect(() => { fetchHistory(); }, []);

    const handleSend = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!message.trim()) return;

        try {
            setLoading(true);
            setStatus(null);
            const body: any = { message };
            if (targetRole !== 'ALL') body.role = targetRole;

            const res = await api.post('/admin/notifications/send', body);

            if (res.data.success) {
                setStatus({ type: 'success', text: `✅ ${res.data.message}` });
                setMessage('');
                fetchHistory();
            } else {
                setStatus({ type: 'error', text: 'Failed: ' + res.data.message });
            }
        } catch (error: any) {
            const msg = error?.response?.data?.message || 'Could not reach the server.';
            setStatus({ type: 'error', text: '❌ ' + msg });
        } finally {
            setLoading(false);
        }
    };

    const formatTime = (iso: string) => {
        try {
            const d = new Date(iso);
            const diff = (Date.now() - d.getTime()) / 1000;
            if (diff < 60) return 'Just now';
            if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
            if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
            return d.toLocaleDateString();
        } catch { return ''; }
    };

    return (
        <div className="fade-in">
            <div className="page-header">
                <div className="page-header-left">
                    <h2><Bell size={22} style={{ color: 'var(--accent-primary)' }} /> Broadcast Center</h2>
                    <p>Send targeted alerts to users on the platform</p>
                </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem', alignItems: 'start' }}>
                {/* Compose Form */}
                <div className="card">
                    <h3 style={{ fontSize: '0.95rem', fontWeight: 600, marginBottom: '1.25rem', display: 'flex', alignItems: 'center', gap: 8 }}>
                        <Send size={16} color="var(--accent-primary)" /> New Broadcast
                    </h3>
                    <form onSubmit={handleSend} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                        <div>
                            <label>Target Audience</label>
                            <select value={targetRole} onChange={e => setTargetRole(e.target.value)} style={{ width: '100%' }}>
                                <option value="ALL">All Verified Users</option>
                                <option value="CLINIC">Clinics Only</option>
                                <option value="PHARMACY">Pharmacies Only</option>
                                <option value="DRIVER">Drivers Only</option>
                            </select>
                        </div>
                        <div>
                            <label>Message</label>
                            <textarea
                                value={message}
                                onChange={e => setMessage(e.target.value)}
                                rows={5}
                                placeholder="Type your notification message here..."
                                style={{ width: '100%', resize: 'vertical' }}
                            />
                        </div>

                        {status && (
                            <div style={{
                                padding: '0.75rem 1rem', borderRadius: 8,
                                background: status.type === 'success' ? 'rgba(16,185,129,0.1)' : 'rgba(239,68,68,0.1)',
                                color: status.type === 'success' ? 'var(--status-success)' : 'var(--status-danger)',
                                fontSize: '0.875rem', fontWeight: 500
                            }}>
                                {status.text}
                            </div>
                        )}

                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: '0.25rem' }}>
                            <span style={{ fontSize: '0.78rem', color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', gap: 6 }}>
                                <Users size={13} /> Sending to: <strong style={{ color: 'var(--text-primary)' }}>{AUDIENCE_LABELS[targetRole]}</strong>
                            </span>
                            <button type="submit" className="btn btn-primary" disabled={loading || !message.trim()}>
                                {loading ? <RefreshCw size={15} className="spin" /> : <Send size={15} />}
                                Broadcast
                            </button>
                        </div>
                    </form>
                </div>

                {/* History */}
                <div className="card">
                    <h3 style={{ fontSize: '0.95rem', fontWeight: 600, marginBottom: '1rem', display: 'flex', alignItems: 'center', gap: 8 }}>
                        <Clock size={16} color="var(--accent-secondary)" /> Recent Notifications
                    </h3>

                    {histLoading ? (
                        <div style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-secondary)' }}>
                            <RefreshCw className="spin" size={20} style={{ display: 'block', margin: '0 auto' }} />
                        </div>
                    ) : history.length === 0 ? (
                        <div className="empty-state" style={{ padding: '2rem' }}>
                            <Bell size={28} />
                            <p>No notifications sent yet.</p>
                        </div>
                    ) : (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, maxHeight: 400, overflowY: 'auto' }}>
                            {history.map(n => (
                                <div key={n.id} style={{
                                    padding: '0.875rem',
                                    background: 'var(--bg-surface-elevated)',
                                    borderRadius: 8,
                                    border: '1px solid var(--border-subtle)',
                                }}>
                                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                                        <span style={{ fontWeight: 600, fontSize: '0.85rem' }}>{n.title}</span>
                                        <span style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>{formatTime(n.created_at)}</span>
                                    </div>
                                    <p style={{ fontSize: '0.82rem', color: 'var(--text-secondary)', lineHeight: 1.5 }}>{n.message}</p>
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
};
