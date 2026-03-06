import React, { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { Phone, Lock, ArrowRight, Loader2, Zap } from 'lucide-react';
import api from '../lib/api';

export const Login: React.FC = () => {
    const [phone, setPhone] = useState('');
    const [otp, setOtp] = useState('');
    const [step, setStep] = useState<'phone' | 'otp'>('phone');
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');
    const { login } = useAuth();

    const handleRequestOtp = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);
        setError('');
        try {
            const res = await api.post('/auth/request-otp', { phone });
            if (res.data.success) {
                setStep('otp');
            }
        } catch (err: any) {
            setError(err.response?.data?.message || 'Failed to send OTP');
        } finally {
            setLoading(false);
        }
    };

    const handleLogin = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);
        setError('');
        try {
            await login(phone, otp);
        } catch (err: any) {
            setError(err.message || 'Login failed');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen flex flex-col items-center justify-center p-6 bg-slate-50">
            <div className="w-full max-w-md space-y-8">
                <div className="text-center">
                    <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl primary-gradient mb-6">
                        <Zap className="text-white" size={32} />
                    </div>
                    <h1 className="text-3xl font-bold tracking-tight text-slate-900">Afya Links</h1>
                    <p className="mt-2 text-slate-600">Delivery Partner Portal</p>
                </div>

                <div className="bg-white p-8 rounded-3xl shadow-xl shadow-slate-200/50 border border-slate-100">
                    {error && (
                        <div className="mb-6 p-4 bg-red-50 text-red-600 text-sm rounded-xl border border-red-100 flex items-center gap-2">
                            <span className="w-1.5 h-1.5 rounded-full bg-red-600" />
                            {error}
                        </div>
                    )}

                    {step === 'phone' ? (
                        <form onSubmit={handleRequestOtp} className="space-y-6">
                            <div className="space-y-2">
                                <label className="text-sm font-semibold text-slate-700 ml-1">Phone Number</label>
                                <div className="relative">
                                    <Phone className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={20} />
                                    <input
                                        type="tel"
                                        placeholder="+256..."
                                        className="input-field pl-12"
                                        value={phone}
                                        onChange={(e) => setPhone(e.target.value)}
                                        required
                                    />
                                </div>
                            </div>
                            <button disabled={loading} className="button-primary w-full group">
                                {loading ? <Loader2 className="animate-spin" size={20} /> : (
                                    <>
                                        Send Verification Code
                                        <ArrowRight className="group-hover:translate-x-1 transition-transform" size={20} />
                                    </>
                                )}
                            </button>
                        </form>
                    ) : (
                        <form onSubmit={handleLogin} className="space-y-6">
                            <div className="space-y-2">
                                <label className="text-sm font-semibold text-slate-700 ml-1">Verification Code</label>
                                <div className="relative">
                                    <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={20} />
                                    <input
                                        type="text"
                                        placeholder="Enter 6-digit code"
                                        className="input-field pl-12 tracking-[0.5em] font-mono"
                                        value={otp}
                                        onChange={(e) => setOtp(e.target.value)}
                                        maxLength={6}
                                        required
                                    />
                                </div>
                                <button
                                    type="button"
                                    onClick={() => setStep('phone')}
                                    className="text-sm text-slate-500 hover:text-slate-900 ml-1"
                                >
                                    Change phone number?
                                </button>
                            </div>
                            <button disabled={loading} className="button-primary w-full group">
                                {loading ? <Loader2 className="animate-spin" size={20} /> : (
                                    <>
                                        Log In
                                        <ArrowRight className="group-hover:translate-x-1 transition-transform" size={20} />
                                    </>
                                )}
                            </button>
                        </form>
                    )}
                </div>

                <p className="text-center text-sm text-slate-500">
                    By logging in, you agree to Afya Links Driver Terms of Service.
                </p>
            </div>
        </div>
    );
};
