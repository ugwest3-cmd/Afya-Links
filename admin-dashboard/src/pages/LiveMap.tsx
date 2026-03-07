import { useEffect, useState } from 'react';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import { Truck, Navigation, RefreshCw } from 'lucide-react';
import api from '../utils/api';

// Fix for default marker icons in React-Leaflet
import 'leaflet/dist/leaflet.css';

// Custom icons
const driverIcon = new L.DivIcon({
    html: `<div style="background-color: #3b82f6; width: 32px; height: 32px; border-radius: 50%; display: flex; align-items: center; justify-content: center; border: 2px solid white; box-shadow: 0 0 10px rgba(59, 130, 246, 0.5);"><svg viewBox="0 0 24 24" width="18" height="18" stroke="white" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"><rect x="1" y="3" width="15" height="13"></rect><polygon points="16 8 20 8 23 11 23 16 16 16 16 8"></polygon><circle cx="5.5" cy="18.5" r="2.5"></circle><circle cx="18.5" cy="18.5" r="2.5"></circle></svg></div>`,
    className: 'custom-driver-icon',
    iconSize: [32, 32],
    iconAnchor: [16, 16],
});

export const LiveMap = () => {
    const [locations, setLocations] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);

    const fetchLocations = async () => {
        try {
            setLoading(true);
            const res = await api.get('/admin/locations');
            if (res.data.success) {
                setLocations(res.data.locations);
            }
        } catch (e) {
            console.error('Failed to fetch locations:', e);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchLocations();
        const interval = setInterval(fetchLocations, 30000); // Update every 30s
        return () => clearInterval(interval);
    }, []);

    return (
        <div className="fade-in">
            <div className="page-header" style={{ marginBottom: '1.5rem' }}>
                <div className="page-header-left">
                    <h2><Navigation size={22} style={{ color: 'var(--accent-primary)' }} /> Live Logistics Command</h2>
                    <p>Real-time distribution of active delivery units</p>
                </div>
                <div style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}>
                    <div className="glass-panel" style={{ padding: '0.5rem 1rem', display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <div className="status-dot" />
                        <span style={{ fontSize: '0.8rem', fontWeight: 600 }}>{locations.length} Units Online</span>
                    </div>
                    <button className="btn btn-secondary" onClick={fetchLocations} disabled={loading}>
                        <RefreshCw size={15} className={loading ? 'spin' : ''} />
                        Refresh
                    </button>
                </div>
            </div>

            <div className="map-container">
                <MapContainer center={[0.3476, 32.5825]} zoom={13} style={{ height: '100%', width: '100%' }}>
                    <TileLayer
                        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
                        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                    />
                    {locations.map((loc) => (
                        <Marker
                            key={loc.driver?.id}
                            position={[loc.latitude, loc.longitude]}
                            icon={driverIcon}
                        >
                            <Popup>
                                <div style={{ minWidth: '150px' }}>
                                    <div style={{ fontWeight: 700, fontSize: '1rem', marginBottom: '4px' }}>{loc.driver?.name || 'Unknown Driver'}</div>
                                    <div style={{ color: '#666', fontSize: '0.8rem', marginBottom: '8px' }}>{loc.driver?.phone}</div>
                                    <div style={{ borderTop: '1px solid #eee', paddingTop: '8px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                        <span style={{ fontSize: '0.7rem', color: '#888' }}>
                                            Last seen: {new Date(loc.updated_at).toLocaleTimeString()}
                                        </span>
                                        <Truck size={14} color="#3b82f6" />
                                    </div>
                                </div>
                            </Popup>
                        </Marker>
                    ))}
                </MapContainer>
            </div>
        </div>
    );
};
