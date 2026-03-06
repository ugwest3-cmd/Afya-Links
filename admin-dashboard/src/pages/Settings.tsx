import { useState, useEffect } from 'react';
import { Settings as SettingsIcon, Save, RefreshCw, AlertCircle, CheckCircle2, Percent, DollarSign, Wallet } from 'lucide-react';
import api from '../utils/api';

interface CommissionSettings {
    pharmacy_percent: number;
    driver_percent: number;
    min_payout: number;
}

export const Settings = () => {
    const [commissions, setCommissions] = useState<CommissionSettings>({
        pharmacy_percent: 8,
        driver_percent: 15,
        min_payout: 500000
    });
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [success, setSuccess] = useState<string | null>(null);

    const fetchSettings = async () => {
        try {
            setLoading(true);
            setError(null);
            const res = await api.get('/admin/settings');
            if (res.data.success && res.data.settings.commissions) {
                setCommissions(res.data.settings.commissions);
            }
        } catch (err: any) {
            setError('Failed to load settings. Using defaults.');
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => { fetchSettings(); }, []);

    const handleSave = async (e: React.FormEvent) => {
        e.preventDefault();
        try {
            setSaving(true);
            setError(null);
            setSuccess(null);
            const res = await api.post('/admin/settings', {
                key: 'commissions',
                value: commissions
            });
            if (res.data.success) {
                setSuccess('Settings updated successfully!');
            }
        } catch (err: any) {
            setError(err.response?.data?.message || 'Failed to save settings');
        } finally {
            setSaving(false);
        }
    };

    if (loading) return (
        <div style={{ display: 'flex', justifyContent: 'center', padding: '4rem' }}>
            <RefreshCw className="spin" size={32} color="var(--accent-primary)" />
        </div>
    );

    return (
        <div className="fade-in" style={{ maxWidth: '800px', margin: '0 auto' }}>
            <div className="page-header" style={{ marginBottom: '2rem' }}>
                <div className="page-header-left">
                    <h2><SettingsIcon size={22} style={{ color: 'var(--accent-primary)' }} /> Platform Settings</h2>
                    <p>Configure global commission rates and financial thresholds</p>
                </div>
            </div>

            {error && (
                <div className="card" style={{ background: 'rgba(239, 68, 68, 0.1)', border: '1px solid var(--status-danger)', color: 'var(--status-danger)', display: 'flex', gap: 12, marginBottom: '1.5rem' }}>
                    <AlertCircle size={20} /> {error}
                </div>
            )}

            {success && (
                <div className="card" style={{ background: 'rgba(16, 185, 129, 0.1)', border: '1px solid var(--status-success)', color: 'var(--status-success)', display: 'flex', gap: 12, marginBottom: '1.5rem' }}>
                    <CheckCircle2 size={20} /> {success}
                </div>
            )}

            <form onSubmit={handleSave} className="card">
                <h3 style={{ fontSize: '1rem', fontWeight: 600, marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: 8 }}>
                    <Percent size={18} color="var(--accent-primary)" /> Commission Rates
                </h3>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '2rem', marginBottom: '2rem' }}>
                    <div>
                        <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
                            Pharmacy Platform Fee (%)
                        </label>
                        <div style={{ position: 'relative' }}>
                            <input
                                type="number"
                                className="input-base"
                                style={{ width: '100%', paddingLeft: '2.5rem' }}
                                value={commissions.pharmacy_percent}
                                onChange={e => setCommissions({ ...commissions, pharmacy_percent: Number(e.target.value) })}
                                step="0.1"
                                min="0"
                                max="100"
                                required
                            />
                            <Percent size={16} style={{ position: 'absolute', left: '0.875rem', top: '50%', transform: 'translateY(-50%)', opacity: 0.5 }} />
                        </div>
                        <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.5rem' }}>
                            The percentage AfyaLinks takes from pharmacy sales.
                        </p>
                    </div>

                    <div>
                        <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
                            Driver Platform Fee (%)
                        </label>
                        <div style={{ position: 'relative' }}>
                            <input
                                type="number"
                                className="input-base"
                                style={{ width: '100%', paddingLeft: '2.5rem' }}
                                value={commissions.driver_percent}
                                onChange={e => setCommissions({ ...commissions, driver_percent: Number(e.target.value) })}
                                step="0.1"
                                min="0"
                                max="100"
                                required
                            />
                            <Percent size={16} style={{ position: 'absolute', left: '0.875rem', top: '50%', transform: 'translateY(-50%)', opacity: 0.5 }} />
                        </div>
                        <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.5rem' }}>
                            The percentage AfyaLinks takes from delivery fees.
                        </p>
                    </div>
                </div>

                <hr style={{ border: 'none', borderTop: '1px solid var(--border-subtle)', margin: '2rem 0' }} />

                <h3 style={{ fontSize: '1rem', fontWeight: 600, marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: 8 }}>
                    <Wallet size={18} color="var(--accent-secondary)" /> Payout Thresholds
                </h3>

                <div>
                    <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
                        Minimum Withdrawal Amount (UGX)
                    </label>
                    <div style={{ position: 'relative', maxWidth: '300px' }}>
                        <input
                            type="number"
                            className="input-base"
                            style={{ width: '100%', paddingLeft: '2.5rem' }}
                            value={commissions.min_payout}
                            onChange={e => setCommissions({ ...commissions, min_payout: Number(e.target.value) })}
                            min="0"
                            required
                        />
                        <DollarSign size={16} style={{ position: 'absolute', left: '0.875rem', top: '50%', transform: 'translateY(-50%)', opacity: 0.5 }} />
                    </div>
                    <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.5rem' }}>
                        Pharmacies cannot request a payout until their balance reaches this amount.
                    </p>
                </div>

                <div style={{ marginTop: '2.5rem', display: 'flex', justifyContent: 'flex-end', gap: '1rem' }}>
                    <button type="button" className="btn btn-secondary" onClick={fetchSettings} disabled={saving}>
                        Discard Changes
                    </button>
                    <button type="submit" className="btn btn-primary" disabled={saving}>
                        {saving ? <RefreshCw className="spin" size={16} /> : <Save size={16} />}
                        Save Settings
                    </button>
                </div>
            </form>
        </div>
    );
};
