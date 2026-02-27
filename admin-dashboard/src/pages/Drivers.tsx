import { useState, useEffect } from 'react';
import { Truck, RefreshCw, Save } from 'lucide-react';

export const Drivers = () => {
    const [drivers, setDrivers] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);
    const token = localStorage.getItem('afyalinks_admin_token');

    const fetchDrivers = async () => {
        try {
            setLoading(true);
            const res = await fetch('http://localhost:5000/api/admin/users', {
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            });
            const data = await res.json();
            if (data.success) {
                // Filter only drivers
                setDrivers(data.users.filter((u: any) => u.role === 'DRIVER' && u.is_verified));
            }
        } catch (error) {
            console.error('Failed to fetch drivers:', error);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (token) fetchDrivers();
    }, [token]);

    const handleUpdateProfile = async (driverId: string, region: string, availableHours: string) => {
        try {
            const res = await fetch(`http://localhost:5000/api/admin/drivers/${driverId}/profile`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                },
                body: JSON.stringify({ region, available_hours: availableHours })
            });

            if (res.ok) {
                alert('Driver profile updated successfully');
            } else {
                alert('Failed to update driver');
            }
        } catch (e) {
            console.error(e);
            alert('Error updating driver');
        }
    };

    return (
        <div className="fade-in">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
                <div>
                    <h2 className="text-h2" style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <Truck size={28} style={{ color: 'var(--accent-primary)' }} />
                        Driver Management
                    </h2>
                    <p className="text-muted">Set operating regions and availability hours for automatic assignment.</p>
                </div>
                <button
                    onClick={fetchDrivers}
                    className="btn btn-secondary"
                    disabled={loading}
                >
                    <RefreshCw size={18} className={loading ? 'spin' : ''} />
                    Refresh
                </button>
            </div>

            <div className="card">
                <div style={{ overflowX: 'auto' }}>
                    <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
                        <thead>
                            <tr style={{ borderBottom: '1px solid var(--border-color)', color: 'var(--text-secondary)' }}>
                                <th style={{ padding: '1rem', fontWeight: 500 }}>Driver Name</th>
                                <th style={{ padding: '1rem', fontWeight: 500 }}>Phone</th>
                                <th style={{ padding: '1rem', fontWeight: 500 }}>Assigned Region</th>
                                <th style={{ padding: '1rem', fontWeight: 500 }}>Available Hours</th>
                                <th style={{ padding: '1rem', fontWeight: 500 }}>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {drivers.length === 0 ? (
                                <tr>
                                    <td colSpan={5} style={{ padding: '2rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                                        No verified drivers found.
                                    </td>
                                </tr>
                            ) : (
                                drivers.map((driver) => (
                                    <DriverRow key={driver.id} driver={driver} onSave={handleUpdateProfile} />
                                ))
                            )}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    );
};

const DriverRow = ({ driver, onSave }: { driver: any, onSave: (id: string, r: string, h: string) => void }) => {
    // These should ideally come from driver_profiles, but for MVP we use placeholder states
    const [region, setRegion] = useState('Kampala Central');
    const [hours, setHours] = useState('08:00-17:00');

    return (
        <tr style={{ borderBottom: '1px solid var(--border-color)' }}>
            <td style={{ padding: '1rem', fontWeight: 500 }}>{driver.name || '---'}</td>
            <td style={{ padding: '1rem', fontFamily: 'monospace' }}>{driver.phone}</td>
            <td style={{ padding: '1rem' }}>
                <input
                    type="text"
                    value={region}
                    onChange={(e) => setRegion(e.target.value)}
                    style={{ padding: '0.5rem', borderRadius: '4px', border: '1px solid var(--border-color)', background: 'var(--bg-primary)', color: 'var(--text-primary)' }}
                />
            </td>
            <td style={{ padding: '1rem' }}>
                <input
                    type="text"
                    value={hours}
                    onChange={(e) => setHours(e.target.value)}
                    style={{ padding: '0.5rem', borderRadius: '4px', border: '1px solid var(--border-color)', background: 'var(--bg-primary)', color: 'var(--text-primary)', width: '120px' }}
                    placeholder="e.g. 08:00-17:00"
                />
            </td>
            <td style={{ padding: '1rem' }}>
                <button
                    onClick={() => onSave(driver.id, region, hours)}
                    className="btn btn-primary"
                    style={{ padding: '0.5rem 1rem', fontSize: '0.9rem' }}
                >
                    <Save size={16} /> Save
                </button>
            </td>
        </tr>
    );
};
