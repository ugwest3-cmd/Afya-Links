import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { MapPin, Phone, Building2, ChevronLeft, CheckCircle2, Navigation, Loader2 } from 'lucide-react';
import api from '../lib/api';
import { useGeolocation } from '../hooks/useGeolocation';

interface OrderDetail {
    id: string;
    order_code: string;
    delivery_address: string;
    status: string;
    pharmacy: { business_name: string; address: string; phone: string };
    clinic: { business_name: string; phone: string };
}

export const OrderDetail: React.FC = () => {
    const { id } = useParams<{ id: string }>();
    const navigate = useNavigate();
    const [order, setOrder] = useState<OrderDetail | null>(null);
    const [loading, setLoading] = useState(true);
    const [updating, setUpdating] = useState(false);

    // Enable real-time tracking if the order is picked up but not delivered
    const isTrackingActive = order?.status === 'IN_TRANSIT';
    useGeolocation(isTrackingActive);

    const fetchOrder = async () => {
        try {
            setLoading(true);
            const res = await api.get(`/orders/${id}`); // Needs backend verification
            if (res.data.success) {
                setOrder(res.data.order);
            }
        } catch (err) {
            console.error('Failed to fetch order', err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchOrder();
    }, [id]);

    const handleUpdateStatus = async (newStatus: string) => {
        try {
            setUpdating(true);
            const endpoint = newStatus === 'IN_TRANSIT' ? `/orders/${id}/pickup` : `/orders/${id}/deliver`;
            const res = await api.post(endpoint);
            if (res.data.success) {
                setOrder(prev => prev ? { ...prev, status: newStatus } : null);
            }
        } catch (err) {
            console.error('Failed to update status', err);
        } finally {
            setUpdating(false);
        }
    };

    if (loading) return (
        <div className="h-screen flex items-center justify-center">
            <Loader2 className="animate-spin text-slate-400" size={32} />
        </div>
    );

    if (!order) return <div className="p-6 text-center">Order not found</div>;

    return (
        <div className="min-h-screen bg-slate-50">
            <header className="bg-white p-6 border-b border-slate-100 sticky top-0 z-10 flex items-center gap-4">
                <button onClick={() => navigate(-1)} className="p-2 hover:bg-slate-50 rounded-xl transition-colors">
                    <ChevronLeft size={24} />
                </button>
                <h1 className="text-xl font-bold">Order #{order.order_code}</h1>
            </header>

            <main className="p-6 space-y-6">
                {/* Progress Bar Mock */}
                <div className="bg-white p-6 rounded-3xl shadow-sm border border-slate-100 flex items-center justify-between">
                    <div className="flex flex-col items-center gap-2">
                        <div className={`w-10 h-10 rounded-full flex items-center justify-center ${order.status === 'ASSIGNED' ? 'bg-blue-600 text-white' : 'bg-emerald-500 text-white'}`}>
                            <CheckCircle2 size={20} />
                        </div>
                        <span className="text-[10px] font-bold uppercase tracking-tight text-slate-400">Assigned</span>
                    </div>
                    <div className={`h-1 flex-1 mx-2 rounded-full ${order.status !== 'ASSIGNED' ? 'bg-emerald-500' : 'bg-slate-100'}`} />
                    <div className="flex flex-col items-center gap-2">
                        <div className={`w-10 h-10 rounded-full flex items-center justify-center ${order.status === 'IN_TRANSIT' ? 'bg-blue-600 text-white' : (['DELIVERED', 'COMPLETED'].includes(order.status) ? 'bg-emerald-500 text-white' : 'bg-slate-100 text-slate-300')}`}>
                            <Navigation size={20} />
                        </div>
                        <span className="text-[10px] font-bold uppercase tracking-tight text-slate-400">Transit</span>
                    </div>
                    <div className={`h-1 flex-1 mx-2 rounded-full ${['DELIVERED', 'COMPLETED'].includes(order.status) ? 'bg-emerald-500' : 'bg-slate-100'}`} />
                    <div className="flex flex-col items-center gap-2">
                        <div className={`w-10 h-10 rounded-full flex items-center justify-center ${['DELIVERED', 'COMPLETED'].includes(order.status) ? 'bg-emerald-500 text-white' : 'bg-slate-100 text-slate-300'}`}>
                            <CheckCircle2 size={20} />
                        </div>
                        <span className="text-[10px] font-bold uppercase tracking-tight text-slate-400">Dropoff</span>
                    </div>
                </div>

                {/* Pickup Info */}
                <section className="bg-white p-6 rounded-3xl shadow-sm border border-slate-100 space-y-4">
                    <div className="flex items-center gap-2 text-emerald-600 font-bold text-xs uppercase tracking-widest">
                        <div className="w-1.5 h-1.5 rounded-full bg-emerald-600" />
                        Pickup Location
                    </div>
                    <div className="flex items-start gap-3">
                        <Building2 className="text-slate-400 mt-1 shrink-0" size={20} />
                        <div>
                            <p className="font-bold text-slate-900">{order.pharmacy.business_name}</p>
                            <p className="text-sm text-slate-500 leading-relaxed mt-1">{order.pharmacy.address}</p>
                        </div>
                    </div>
                    <a href={`tel:${order.pharmacy.phone}`} className="flex items-center gap-3 p-3 bg-slate-50 rounded-2xl text-slate-700 hover:bg-slate-100 transition-colors">
                        <Phone size={18} className="text-slate-400" />
                        <span className="text-sm font-medium">Call Pharmacy</span>
                    </a>
                </section>

                {/* Dropoff Info */}
                <section className="bg-white p-6 rounded-3xl shadow-sm border border-slate-100 space-y-4">
                    <div className="flex items-center gap-2 text-blue-600 font-bold text-xs uppercase tracking-widest">
                        <div className="w-1.5 h-1.5 rounded-full bg-blue-600" />
                        Drop-off Location
                    </div>
                    <div className="flex items-start gap-3">
                        <MapPin className="text-slate-400 mt-1 shrink-0" size={20} />
                        <div>
                            <p className="font-bold text-slate-900">{order.clinic.business_name}</p>
                            <p className="text-sm text-slate-500 leading-relaxed mt-1">{order.delivery_address}</p>
                        </div>
                    </div>
                    <a href={`tel:${order.clinic.phone}`} className="flex items-center gap-3 p-3 bg-slate-50 rounded-2xl text-slate-700 hover:bg-slate-100 transition-colors">
                        <Phone size={18} className="text-slate-400" />
                        <span className="text-sm font-medium">Call Clinic</span>
                    </a>
                </section>

                {/* Action Button */}
                <div className="sticky bottom-6 pt-4">
                    {order.status === 'ASSIGNED' && (
                        <button
                            disabled={updating}
                            onClick={() => handleUpdateStatus('IN_TRANSIT')}
                            className="w-full button-primary bg-slate-900 h-16 shadow-xl shadow-slate-900/20"
                        >
                            {updating ? <Loader2 className="animate-spin" size={24} /> : 'Confirm Pickup'}
                        </button>
                    )}
                    {order.status === 'IN_TRANSIT' && (
                        <button
                            disabled={updating}
                            onClick={() => handleUpdateStatus('DELIVERED')}
                            className="w-full button-primary bg-emerald-600 hover:bg-emerald-700 h-16 shadow-xl shadow-emerald-600/20"
                        >
                            {updating ? <Loader2 className="animate-spin" size={24} /> : 'Confirm Delivery'}
                        </button>
                    )}
                    {order.status === 'DELIVERED' && (
                        <div className="bg-emerald-50 p-4 rounded-2xl border border-emerald-100 text-center">
                            <p className="text-emerald-700 font-bold">Delivery Confirmed</p>
                            <p className="text-xs text-emerald-600/70 mt-1">Awaiting clinic receipt confirmation</p>
                        </div>
                    )}
                </div>
            </main>
        </div>
    );
};
