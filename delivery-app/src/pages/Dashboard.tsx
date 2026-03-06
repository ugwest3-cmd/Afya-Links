import React, { useEffect, useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { Package, MapPin, Navigation, CheckCircle2, Clock, LogOut, ChevronRight, RefreshCw, LayoutDashboard, Settings } from 'lucide-react';
import { Link } from 'react-router-dom';
import api from '../lib/api';

interface Delivery {
    id: string;
    order_id: string;
    orders: {
        order_code: string;
        delivery_address: string;
        status: string;
    };
    pickup_time: string | null;
    dropoff_time: string | null;
}

export const Dashboard: React.FC = () => {
    const { user, logout } = useAuth();
    const [deliveries, setDeliveries] = useState<Delivery[]>([]);
    const [loading, setLoading] = useState(true);

    const fetchDeliveries = async () => {
        try {
            setLoading(true);
            const res = await api.get('/users/me/deliveries'); // This endpoint needs to be verified/added
            if (res.data.success) {
                setDeliveries(res.data.deliveries);
            }
        } catch (err) {
            console.error('Failed to fetch deliveries', err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchDeliveries();
    }, []);

    const pendingPickups = deliveries.filter(d => !d.pickup_time);
    const activeDeliveries = deliveries.filter(d => d.pickup_time && !d.dropoff_time);

    return (
        <div className="min-h-screen bg-slate-50 pb-20">
            {/* Header */}
            <header className="primary-gradient text-white p-6 rounded-b-[2.5rem] shadow-lg shadow-slate-200">
                <div className="flex justify-between items-start mb-6">
                    <div>
                        <p className="text-slate-300 text-sm font-medium">Welcome back,</p>
                        <h1 className="text-2xl font-bold">{user?.name || 'Driver'}</h1>
                    </div>
                    <button onClick={logout} className="p-2 bg-white/10 rounded-xl hover:bg-white/20 transition-colors">
                        <LogOut size={20} />
                    </button>
                </div>

                <div className="grid grid-cols-2 gap-4">
                    <div className="bg-white/10 p-4 rounded-2xl backdrop-blur-sm border border-white/10">
                        <p className="text-white/60 text-xs uppercase tracking-wider font-bold mb-1">Pickups</p>
                        <p className="text-2xl font-bold">{pendingPickups.length}</p>
                    </div>
                    <div className="bg-white/10 p-4 rounded-2xl backdrop-blur-sm border border-white/10">
                        <p className="text-white/60 text-xs uppercase tracking-wider font-bold mb-1">Active</p>
                        <p className="text-2xl font-bold">{activeDeliveries.length}</p>
                    </div>
                </div>
            </header>

            {/* Main Content */}
            <main className="p-6 space-y-8">
                {/* Active Tasks */}
                <section className="space-y-4">
                    <div className="flex items-center justify-between">
                        <h2 className="text-lg font-bold text-slate-900">Current Task</h2>
                        <button onClick={fetchDeliveries} className="text-slate-400 hover:text-slate-900 transition-colors">
                            <RefreshCw size={20} className={loading ? 'animate-spin' : ''} />
                        </button>
                    </div>

                    {activeDeliveries.length > 0 ? (
                        activeDeliveries.map(delivery => (
                            <Link to={`/orders/${delivery.order_id}`} key={delivery.id} className="block bg-white p-5 rounded-3xl shadow-sm border border-slate-100 space-y-4 relative overflow-hidden group">
                                <div className="absolute top-0 right-0 w-16 h-16 bg-blue-50 -mr-8 -mt-8 rounded-full group-hover:scale-110 transition-transform" />

                                <div className="flex items-center gap-3">
                                    <div className="w-10 h-10 rounded-xl bg-blue-50 flex items-center justify-center text-blue-600">
                                        <Navigation size={20} />
                                    </div>
                                    <div>
                                        <p className="text-xs text-slate-400 font-bold uppercase tracking-wide">#{delivery.orders.order_code}</p>
                                        <p className="text-sm font-bold text-slate-900">Heading to Drop-off</p>
                                    </div>
                                </div>

                                <div className="space-y-3">
                                    <div className="flex items-start gap-2">
                                        <MapPin size={16} className="text-slate-400 mt-0.5 shrink-0" />
                                        <p className="text-sm text-slate-600 leading-relaxed">{delivery.orders.delivery_address}</p>
                                    </div>
                                </div>

                                <div className="w-full button-primary bg-blue-600 hover:bg-blue-700 mt-2">
                                    View Navigation Details
                                    <ChevronRight size={18} />
                                </div>
                            </Link>
                        ))
                    ) : (
                        <div className="bg-white p-8 rounded-3xl border border-dotted border-slate-300 flex flex-col items-center justify-center text-center space-y-3">
                            <div className="w-12 h-12 rounded-full bg-slate-50 flex items-center justify-center text-slate-300">
                                <Package size={24} />
                            </div>
                            <p className="text-sm text-slate-400 font-medium tracking-tight">No active deliveries right now.</p>
                        </div>
                    )}
                </section>

                {/* Pending Pickups */}
                <section className="space-y-4">
                    <h2 className="text-lg font-bold text-slate-900">Pending Pickups</h2>
                    <div className="space-y-3">
                        {pendingPickups.map(delivery => (
                            <Link to={`/orders/${delivery.order_id}`} key={delivery.id} className="bg-white p-4 rounded-2xl shadow-sm border border-slate-100 flex items-center justify-between group active:bg-slate-50 transition-colors cursor-pointer">
                                <div className="flex items-center gap-4">
                                    <div className="w-12 h-12 rounded-xl bg-emerald-50 flex items-center justify-center text-emerald-600">
                                        <Package size={24} />
                                    </div>
                                    <div>
                                        <p className="text-sm font-bold text-slate-900">Order #{delivery.orders.order_code}</p>
                                        <p className="text-xs text-slate-500 font-medium">Ready for pickup</p>
                                    </div>
                                </div>
                                <ChevronRight size={20} className="text-slate-300 group-hover:text-slate-900 transition-colors" />
                            </Link>
                        ))}
                        {pendingPickups.length === 0 && (
                            <p className="text-center text-slate-400 text-sm py-4">All caught up!</p>
                        )}
                    </div>
                </section>
            </main>

            {/* Bottom Nav Mock (Floating) */}
            <nav className="fixed bottom-6 left-6 right-6 h-16 bg-white/80 backdrop-blur-lg rounded-2xl shadow-2xl shadow-slate-200 border border-white/50 flex items-center justify-around px-4">
                <button className="w-12 h-12 rounded-xl bg-slate-900 text-white flex items-center justify-center shadow-lg shadow-slate-900/20">
                    <LayoutDashboard size={22} />
                </button>
                <button className="w-12 h-12 rounded-xl text-slate-400 flex items-center justify-center hover:bg-slate-50 transition-colors" title="History">
                    <Clock size={22} />
                </button>
                <button className="w-12 h-12 rounded-xl text-slate-400 flex items-center justify-center hover:bg-slate-50 transition-colors" title="Settings">
                    <Settings size={22} />
                </button>
            </nav>
        </div>
    );
};

