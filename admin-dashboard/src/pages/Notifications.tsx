import { useState } from 'react';
import { Bell, Send } from 'lucide-react';

export const Notifications = () => {
    const [message, setMessage] = useState('');
    const [targetRole, setTargetRole] = useState('ALL');
    const [loading, setLoading] = useState(false);
    const token = localStorage.getItem('afyalinks_admin_token');

    const handleSend = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!message) return;

        try {
            setLoading(true);
            const body: any = { message };
            if (targetRole !== 'ALL') body.role = targetRole;

            const res = await fetch('http://localhost:5000/api/admin/notifications/send', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                },
                body: JSON.stringify(body)
            });
            const data = await res.json();

            if (data.success) {
                alert('Notification broadcasted successfully!');
                setMessage('');
            } else {
                alert('Failed: ' + data.message);
            }
        } catch (error) {
            console.error('Failed to send notification:', error);
            alert('Error sending notification');
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

// Need RefreshCw for the loading state spinner above
import { RefreshCw } from 'lucide-react';
