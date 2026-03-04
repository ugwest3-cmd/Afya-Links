import { useState, useEffect } from 'react';
import { Truck, Plus, Trash2, RefreshCw, Save, AlertCircle } from 'lucide-react';
import api from '../utils/api';

interface RouteAssignment {
    id: string;
    clinic_id: string;
    driver_id: string;
    delivery_fee: number;
    notes: string | null;
    is_active: boolean;
    clinic: { id: string; name: string; phone: string } | null;
    driver: { id: string; name: string; phone: string } | null;
}

interface UserOption {
    id: string;
    name: string;
    phone: string;
    role: string;
}

export const Drivers = () => {
    const [routes, setRoutes] = useState<RouteAssignment[]>([]);
    const [clinics, setClinics] = useState<UserOption[]>([]);
    const [drivers, setDrivers] = useState<UserOption[]>([]);
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [successMsg, setSuccessMsg] = useState<string | null>(null);

    // Form state for new/edit assignment
    const [form, setForm] = useState({
        clinic_id: '',
        driver_id: '',
        delivery_fee: '',
        notes: ''
    });

    const fetchAll = async () => {
        setLoading(true);
        setError(null);
        try {
            const [routesRes, usersRes] = await Promise.all([
                api.get('/admin/driver-routes'),
                api.get('/admin/users')
            ]);
            if (routesRes.data.success) setRoutes(routesRes.data.routes || []);
            if (usersRes.data.success) {
                const users: UserOption[] = usersRes.data.users;
                setClinics(users.filter(u => u.role === 'CLINIC'));
                setDrivers(users.filter(u => u.role === 'DRIVER'));
            }
        } catch (e: any) {
            setError(e?.response?.data?.message || 'Failed to load data');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => { fetchAll(); }, []);

    const handleSave = async () => {
        if (!form.clinic_id || !form.driver_id || !form.delivery_fee) {
            setError('Please fill in all required fields');
            return;
        }
        setSaving(true);
        setError(null);
        setSuccessMsg(null);
        try {
            const res = await api.post('/admin/driver-routes', {
                clinic_id: form.clinic_id,
                driver_id: form.driver_id,
                delivery_fee: Number(form.delivery_fee),
                notes: form.notes || null
            });
            if (res.data.success) {
                setSuccessMsg('Route assignment saved successfully!');
                setForm({ clinic_id: '', driver_id: '', delivery_fee: '', notes: '' });
                fetchAll();
            } else {
                setError(res.data.message || 'Failed to save');
            }
        } catch (e: any) {
            setError(e?.response?.data?.message || 'Error saving assignment');
        } finally {
            setSaving(false);
        }
    };

    const handleDelete = async (clinicId: string, clinicName: string) => {
        if (!window.confirm(`Remove the driver assignment for "${clinicName}"?`)) return;
        try {
            const res = await api.delete(`/admin/driver-routes/${clinicId}`);
            if (res.data.success) {
                setSuccessMsg('Assignment removed.');
                fetchAll();
            } else {
                setError(res.data.message || 'Failed to remove');
            }
        } catch (e: any) {
            setError(e?.response?.data?.message || 'Error removing assignment');
        }
    };

    const handleEdit = (route: RouteAssignment) => {
        setForm({
            clinic_id: route.clinic_id,
            driver_id: route.driver_id,
            delivery_fee: String(route.delivery_fee),
            notes: route.notes || ''
        });
        window.scrollTo({ top: 0, behavior: 'smooth' });
    };

    return (
        <div className="fade-in">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '2rem' }}>
                <div>
                    <h2 className="text-h2" style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <Truck size={28} style={{ color: 'var(--accent-primary)' }} />
                        Clinic-Driver Route Assignments
                    </h2>
                    <p className="text-muted">
                        Assign a driver to each clinic route. Set the delivery fee for that specific route.
                        When a clinic places an order, the driver is automatically assigned.
                    </p>
                </div>
                <button onClick={fetchAll} className="btn btn-secondary" disabled={loading}>
                    <RefreshCw size={18} className={loading ? 'spin' : ''} />
                    Refresh
                </button>
            </div>

            {/* Alerts */}
            {error && (
                <div className="card" style={{ background: 'rgba(239,83,80,0.08)', border: '1px solid #ef5350', color: '#ef5350', marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <AlertCircle size={18} />
                    {error}
                </div>
            )}
            {successMsg && (
                <div className="card" style={{ background: 'rgba(102,187,106,0.1)', border: '1px solid #66bb6a', color: '#66bb6a', marginBottom: '1.5rem' }}>
                    ✅ {successMsg}
                </div>
            )}

            {/* Assignment Form */}
            <div className="card" style={{ marginBottom: '2rem' }}>
                <h3 style={{ marginBottom: '1.2rem', fontSize: '1rem', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <Plus size={18} style={{ color: 'var(--accent-primary)' }} />
                    Add / Update Route Assignment
                </h3>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem', marginBottom: '1rem' }}>
                    <div>
                        <label style={{ display: 'block', fontSize: '0.8rem', color: 'var(--text-secondary)', marginBottom: '4px', fontWeight: 500 }}>
                            Clinic *
                        </label>
                        <select
                            value={form.clinic_id}
                            onChange={e => setForm(f => ({ ...f, clinic_id: e.target.value }))}
                            style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', border: '1px solid var(--border-color)', background: 'var(--bg-primary)', color: 'var(--text-primary)', fontSize: '0.9rem' }}
                        >
                            <option value="">— Select Clinic —</option>
                            {clinics.map(c => (
                                <option key={c.id} value={c.id}>{c.name || c.phone}</option>
                            ))}
                        </select>
                    </div>
                    <div>
                        <label style={{ display: 'block', fontSize: '0.8rem', color: 'var(--text-secondary)', marginBottom: '4px', fontWeight: 500 }}>
                            Driver *
                        </label>
                        <select
                            value={form.driver_id}
                            onChange={e => setForm(f => ({ ...f, driver_id: e.target.value }))}
                            style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', border: '1px solid var(--border-color)', background: 'var(--bg-primary)', color: 'var(--text-primary)', fontSize: '0.9rem' }}
                        >
                            <option value="">— Select Driver —</option>
                            {drivers.map(d => (
                                <option key={d.id} value={d.id}>{d.name || d.phone}</option>
                            ))}
                        </select>
                    </div>
                    <div>
                        <label style={{ display: 'block', fontSize: '0.8rem', color: 'var(--text-secondary)', marginBottom: '4px', fontWeight: 500 }}>
                            Delivery Fee (UGX) *
                        </label>
                        <input
                            type="number"
                            value={form.delivery_fee}
                            onChange={e => setForm(f => ({ ...f, delivery_fee: e.target.value }))}
                            placeholder="e.g. 5000"
                            min="0"
                            style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', border: '1px solid var(--border-color)', background: 'var(--bg-primary)', color: 'var(--text-primary)', fontSize: '0.9rem' }}
                        />
                    </div>
                    <div>
                        <label style={{ display: 'block', fontSize: '0.8rem', color: 'var(--text-secondary)', marginBottom: '4px', fontWeight: 500 }}>
                            Notes (optional)
                        </label>
                        <input
                            type="text"
                            value={form.notes}
                            onChange={e => setForm(f => ({ ...f, notes: e.target.value }))}
                            placeholder="e.g. Kampala North daily route"
                            style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', border: '1px solid var(--border-color)', background: 'var(--bg-primary)', color: 'var(--text-primary)', fontSize: '0.9rem' }}
                        />
                    </div>
                </div>
                <button onClick={handleSave} className="btn btn-primary" disabled={saving} style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <Save size={16} />
                    {saving ? 'Saving...' : 'Save Assignment'}
                </button>
            </div>

            {/* Existing Assignments Table */}
            <div className="card">
                <h3 style={{ marginBottom: '1.2rem', fontSize: '1rem', fontWeight: 600 }}>
                    Active Route Assignments ({routes.length})
                </h3>
                <div style={{ overflowX: 'auto' }}>
                    <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
                        <thead>
                            <tr style={{ borderBottom: '1px solid var(--border-color)', color: 'var(--text-secondary)' }}>
                                <th style={{ padding: '0.9rem 1rem', fontWeight: 500 }}>Clinic</th>
                                <th style={{ padding: '0.9rem 1rem', fontWeight: 500 }}>Driver</th>
                                <th style={{ padding: '0.9rem 1rem', fontWeight: 500 }}>Delivery Fee</th>
                                <th style={{ padding: '0.9rem 1rem', fontWeight: 500 }}>Notes</th>
                                <th style={{ padding: '0.9rem 1rem', fontWeight: 500 }}>Status</th>
                                <th style={{ padding: '0.9rem 1rem', fontWeight: 500 }}>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {loading ? (
                                <tr>
                                    <td colSpan={6} style={{ padding: '2rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                                        Loading...
                                    </td>
                                </tr>
                            ) : routes.length === 0 ? (
                                <tr>
                                    <td colSpan={6} style={{ padding: '2.5rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                                        No route assignments yet. Use the form above to assign a driver to a clinic route.
                                    </td>
                                </tr>
                            ) : routes.map(route => {
                                const clinic = Array.isArray(route.clinic) ? route.clinic[0] : route.clinic;
                                const driver = Array.isArray(route.driver) ? route.driver[0] : route.driver;
                                return (
                                    <tr key={route.id} style={{ borderBottom: '1px solid var(--border-color)' }}>
                                        <td style={{ padding: '0.9rem 1rem' }}>
                                            <div style={{ fontWeight: 600 }}>{clinic?.name || 'Unknown'}</div>
                                            <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', fontFamily: 'monospace' }}>{clinic?.phone}</div>
                                        </td>
                                        <td style={{ padding: '0.9rem 1rem' }}>
                                            <div style={{ fontWeight: 600 }}>{driver?.name || 'Unknown'}</div>
                                            <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', fontFamily: 'monospace' }}>{driver?.phone}</div>
                                        </td>
                                        <td style={{ padding: '0.9rem 1rem', fontWeight: 600, color: 'var(--accent-primary)' }}>
                                            UGX {Number(route.delivery_fee).toLocaleString()}
                                        </td>
                                        <td style={{ padding: '0.9rem 1rem', color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
                                            {route.notes || '—'}
                                        </td>
                                        <td style={{ padding: '0.9rem 1rem' }}>
                                            <span style={{
                                                padding: '3px 10px',
                                                borderRadius: '12px',
                                                fontSize: '0.78rem',
                                                fontWeight: 600,
                                                background: route.is_active ? 'rgba(102,187,106,0.12)' : 'rgba(239,83,80,0.1)',
                                                color: route.is_active ? '#66bb6a' : '#ef5350'
                                            }}>
                                                {route.is_active ? 'Active' : 'Inactive'}
                                            </span>
                                        </td>
                                        <td style={{ padding: '0.9rem 1rem' }}>
                                            <div style={{ display: 'flex', gap: '8px' }}>
                                                <button
                                                    onClick={() => handleEdit(route)}
                                                    className="btn btn-secondary"
                                                    style={{ padding: '5px 12px', fontSize: '0.82rem' }}
                                                >
                                                    Edit
                                                </button>
                                                <button
                                                    onClick={() => handleDelete(route.clinic_id, clinic?.name || 'this clinic')}
                                                    style={{ padding: '5px 10px', fontSize: '0.82rem', background: 'transparent', border: '1px solid #ef5350', color: '#ef5350', borderRadius: '6px', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px' }}
                                                >
                                                    <Trash2 size={13} /> Remove
                                                </button>
                                            </div>
                                        </td>
                                    </tr>
                                );
                            })}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    );
};
