import React, { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { Activity, ArrowRight, ShieldCheck } from 'lucide-react';

export const Login = () => {
    const { requestOtp, login } = useAuth();
    const [phone, setPhone] = useState('');
    const [otp, setOtp] = useState('');
    const [step, setStep] = useState<'PHONE' | 'OTP'>('PHONE');
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');

    const handleRequestOtp = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setLoading(true);
        const success = await requestOtp(phone);
        setLoading(false);
        if (success) {
            setStep('OTP');
        } else {
            setError('Failed to request OTP. Ensure your number is registered as ADMIN.');
        }
    };

    const handleLogin = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setLoading(true);
        const success = await login(phone, otp);
        setLoading(false);
        if (!success) {
            setError('Invalid OTP or incomplete ADMIN authorization.');
        }
    };

    return (
        <div className="min-h-screen flex items-center justify-center p-6" style={{ background: 'var(--bg-base)' }}>
            {/* Decorative background glows */}
            <div style={{ position: 'absolute', top: '10%', left: '20%', width: '400px', height: '400px', background: 'var(--accent-primary)', filter: 'blur(150px)', opacity: 0.15, borderRadius: '50%' }} />
            <div style={{ position: 'absolute', bottom: '10%', right: '20%', width: '400px', height: '400px', background: 'var(--accent-secondary)', filter: 'blur(150px)', opacity: 0.1, borderRadius: '50%' }} />

            <div className="glass-panel p-6 fade-in" style={{ width: '100%', maxWidth: '440px', position: 'relative', zIndex: 10 }}>
                <div className="flex flex-col items-center" style={{ marginBottom: '2rem' }}>
                    <div style={{ background: 'rgba(59, 130, 246, 0.1)', padding: '1rem', borderRadius: '16px', marginBottom: '1rem', color: 'var(--accent-primary)' }}>
                        <Activity size={32} />
                    </div>
                    <h2 className="text-h2">AfyaLinks Admin</h2>
                    <p className="text-muted" style={{ marginTop: '0.5rem', textAlign: 'center' }}>Secure management portal for pilot operations</p>
                </div>

                {error && (
                    <div style={{ background: 'rgba(239, 68, 68, 0.15)', color: 'var(--status-danger)', padding: '0.75rem 1rem', borderRadius: '8px', marginBottom: '1.5rem', fontSize: '0.875rem', border: '1px solid rgba(239, 68, 68, 0.3)' }}>
                        {error}
                    </div>
                )}

                {step === 'PHONE' ? (
                    <form onSubmit={handleRequestOtp} className="flex flex-col" style={{ gap: '1rem' }}>
                        <div>
                            <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.875rem', color: 'var(--text-secondary)' }}>Admin Phone Number</label>
                            <input
                                type="tel"
                                className="input-base"
                                placeholder="+256700000000"
                                value={phone}
                                onChange={(e) => setPhone(e.target.value)}
                                required
                            />
                        </div>
                        <button type="submit" className="btn-primary flex items-center justify-center" disabled={loading} style={{ gap: '8px', marginTop: '0.5rem' }}>
                            {loading ? 'Sending...' : 'Request OTP'}
                            <ArrowRight size={18} />
                        </button>
                    </form>
                ) : (
                    <form onSubmit={handleLogin} className="flex flex-col fade-in" style={{ gap: '1rem' }}>
                        <div>
                            <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.875rem', color: 'var(--text-secondary)' }}>Enter 6-digit OTP</label>
                            <input
                                type="text"
                                className="input-base"
                                placeholder="123456"
                                value={otp}
                                onChange={(e) => setOtp(e.target.value)}
                                maxLength={6}
                                required
                                style={{ letterSpacing: '0.5em', textAlign: 'center', fontSize: '1.25rem', fontWeight: 600 }}
                            />
                        </div>
                        <button type="submit" className="btn-primary flex items-center justify-center" disabled={loading} style={{ gap: '8px', marginTop: '0.5rem' }}>
                            <ShieldCheck size={18} />
                            {loading ? 'Verifying...' : 'Authenticate'}
                        </button>
                        <button
                            type="button"
                            onClick={() => setStep('PHONE')}
                            className="btn-secondary"
                            style={{ background: 'transparent', border: 'none', color: 'var(--text-secondary)' }}>
                            Back to phone entry
                        </button>
                    </form>
                )}
            </div>
        </div>
    );
};
