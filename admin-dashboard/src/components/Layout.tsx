
import { NavLink, Outlet } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { ShieldCheck, Activity, FileText, LogOut, LayoutDashboard, Users, Truck, Bell } from 'lucide-react';

const Sidebar = () => {
    const { logout } = useAuth();

    const navItems = [
        { label: 'Dashboard', icon: LayoutDashboard, path: '/' },
        { label: 'User Directory', icon: Users, path: '/users' },
        { label: 'Verifications', icon: ShieldCheck, path: '/verifications' },
        { label: 'Active Orders', icon: Activity, path: '/orders' },
        { label: 'Drivers', icon: Truck, path: '/drivers' },
        { label: 'Notifications', icon: Bell, path: '/notifications' },
        { label: 'Transactions & Invoices', icon: FileText, path: '/invoices' },
    ];

    return (
        <aside className="sidebar">
            <div style={{ padding: '0 1.5rem', marginBottom: '2rem' }}>
                <h1 className="text-h3" style={{ color: 'var(--accent-primary)', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <Activity size={28} />
                    AfyaLinks
                </h1>
                <p className="text-muted" style={{ fontSize: '0.85rem', marginTop: '0.25rem' }}>Admin Portal</p>
            </div>

            <nav style={{ flex: 1, padding: '0 1rem' }}>
                <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                    {navItems.map((item) => (
                        <li key={item.path}>
                            <NavLink
                                to={item.path}
                                style={({ isActive }) => ({
                                    display: 'flex',
                                    alignItems: 'center',
                                    gap: '12px',
                                    padding: '0.75rem 1rem',
                                    borderRadius: '8px',
                                    color: isActive ? 'var(--text-primary)' : 'var(--text-secondary)',
                                    background: isActive ? 'rgba(59, 130, 246, 0.1)' : 'transparent',
                                    textDecoration: 'none',
                                    fontWeight: isActive ? 500 : 400,
                                    transition: 'all 0.2s'
                                })}
                            >
                                <item.icon size={20} style={{ color: 'var(--accent-primary)' }} />
                                {item.label}
                            </NavLink>
                        </li>
                    ))}
                </ul>
            </nav>

            <div style={{ padding: '0 1rem' }}>
                <button
                    onClick={logout}
                    style={{
                        display: 'flex', width: '100%', alignItems: 'center', gap: '12px',
                        padding: '0.75rem 1rem', background: 'transparent', border: 'none',
                        color: 'var(--text-secondary)', cursor: 'pointer', borderRadius: '8px',
                        transition: 'background 0.2s'
                    }}
                    onMouseOver={(e) => e.currentTarget.style.background = 'rgba(239, 68, 68, 0.1)'}
                    onMouseOut={(e) => e.currentTarget.style.background = 'transparent'}
                >
                    <LogOut size={20} style={{ color: 'var(--status-danger)' }} />
                    Sign Out
                </button>
            </div>
        </aside>
    );
};

export const AppLayout = () => {
    return (
        <div className="app-layout fade-in">
            <Sidebar />
            <main className="main-content">
                <Outlet />
            </main>
        </div>
    );
};
