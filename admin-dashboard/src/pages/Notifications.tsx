import { useState } from 'react';
import { Bell, Send, RefreshCw } from 'lucide-react';
import api from '../utils/api';

export const Notifications = () => {
    const [message, setMessage] = useState('');
    const [targetRole, setTargetRole] = useState('ALL');
    const [loading, setLoading] = useState(false);
    const [status, setStatus] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

    const handleSend = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!message) return;

        try {
            setLoading(true);
            setStatus(null);
            const body: any = { message };
            if (targetRole !== 'ALL') body.role = targetRole;

            const res = await api.post('/admin/notifications/send', body);

            if (res.data.success) {
                setStatus({ type: 'success', text: `✅ ${res.data.message}` });
                setMessage('');
            } else {
                setStatus({ type: 'error', text: 'Failed: ' + res.data.message });
            }
        } catch (error: any) {
            const msg = error?.response?.data?.message || 'Could not reach the server. Please check your connection.';
            setStatus({ type: 'error', text: '❌ ' + msg });
            console.error('Failed to send notification:', error);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="fade-in">
            <div style={{ marginBottom: '2rem' }}>
                <h2 className="text-h2" style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <Bell size={28} style={{ color: 'var(--accent-primary)' }} />
                    Broadcast Notifications
                </h2>
                <p className="text-muted">Send platform-wide alerts and updates to users.</p>
            </div>

            <div className="card" style={{ maxWidth: '600px' }}>
                <form onSubmit={handleSend} style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>

                    <div>
                        <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: 500, color: 'var(--text-secondary)' }}>Target Audience</label>
                        <select
                            value={targetRole}
                            onChange={(e) => setTargetRole(e.target.value)}
                            style={{
                                width: '100%', padding: '0.75rem', borderRadius: '8px',
                                border: '1px solid var(--border-color)', background: 'var(--bg-primary)',
                                color: 'var(--text-primary)', outline: 'none'
                            }}
                        >
                            <option value="ALL">All Verified Users</option>
                            <option value="CLINIC">Clinics Only</option>
                            <option value="PHARMACY">Pharmacies Only</option>
                            <option value="DRIVER">Drivers Only</option>
                        </select>
                    </div>

                    <div>
                        <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: 500, color: 'var(--text-secondary)' }}>Notification Message</label>
                        <textarea
                            value={message}
                            onChange={(e) => setMessage(e.target.value)}
                            rows={5}
                            placeholder="Type your alert message here..."
                            style={{
                                width: '100%', padding: '0.75rem', borderRadius: '8px',
                                border: '1px solid var(--border-color)', background: 'var(--bg-primary)',
                                color: 'var(--text-primary)', outline: 'none', resize: 'vertical'
                            }}
                        />
                    </div>

                    {status && (
                        <div style={{
                            padding: '0.75rem 1rem',
                            borderRadius: '8px',
                            background: status.type === 'success' ? 'rgba(34,197,94,0.1)' : 'rgba(239,68,68,0.1)',
                            color: status.type === 'success' ? 'var(--status-success)' : 'var(--status-danger)',
                            fontWeight: 500,
                            fontSize: '0.9rem'
                        }}>
                            {status.text}
                        </div>
                    )}

                    <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
                        <button
                            type="submit"
                            className="btn btn-primary"
                            disabled={loading || !message}
                        >
                            {loading ? <RefreshCw className="spin" size={20} /> : <Send size={20} />}
                            Broadcast Message
                        </button>
                    </div>
                </form>
            </div>
        </div>
    );
};
