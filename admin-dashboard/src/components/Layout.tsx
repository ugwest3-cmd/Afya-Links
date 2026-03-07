import { useState, useEffect } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import {
    ShieldCheck, Activity, LogOut, LayoutDashboard,
    Users, Truck, Bell, Package, Zap, DollarSign, Settings, Navigation
} from 'lucide-react';

const NAV_ITEMS = [
    { label: 'Dashboard', icon: LayoutDashboard, path: '/', section: 'overview' },
    { label: 'Users', icon: Users, path: '/users', section: 'operations' },
    { label: 'Verifications', icon: ShieldCheck, path: '/verifications', section: 'operations' },
    { label: 'Orders', icon: Package, path: '/orders', section: 'operations' },
    { label: 'Live Monitor', icon: Navigation, path: '/map', section: 'operations' },
    { label: 'Drivers', icon: Truck, path: '/drivers', section: 'operations' },
    { label: 'Notifications', icon: Bell, path: '/notifications', section: 'tools' },
    { label: 'Escrow Ledger', icon: DollarSign, path: '/escrow', section: 'tools' },
    { label: 'Payouts', icon: DollarSign, path: '/payouts', section: 'tools' },
    { label: 'Platform Settings', icon: Settings, path: '/settings', section: 'tools' },
];

const PAGE_TITLES: Record<string, { title: string; subtitle: string }> = {
    '/': { title: 'Dashboard', subtitle: 'Platform overview and live stats' },
    '/users': { title: 'User Directory', subtitle: 'Manage all registered users' },
    '/verifications': { title: 'Verifications', subtitle: 'Approve pending KYC submissions' },
    '/orders': { title: 'Active Orders', subtitle: 'Monitor and manage order logistics' },
    '/drivers': { title: 'Driver Management', subtitle: 'Configure driver regions and availability' },
    '/notifications': { title: 'Broadcast Center', subtitle: 'Send platform-wide alerts to users' },
    '/escrow': { title: 'Escrow Ledger', subtitle: 'Manage locked and released funds' },
    '/payouts': { title: 'Pharmacy Payouts', subtitle: 'Review and process withdrawal requests' },
    '/settings': { title: 'Platform Settings', subtitle: 'Configure global commissions and thresholds' },
    '/map': { title: 'Live Logistics Map', subtitle: 'Real-time monitoring of delivery fleet' },
};

const Sidebar = () => {
    const { logout } = useAuth();
    const sections = [
        { key: 'overview', label: 'Overview' },
        { key: 'operations', label: 'Operations' },
        { key: 'tools', label: 'Tools' },
    ];

    return (
        <aside className="sidebar">
            {/* Logo */}
            <div className="sidebar-logo">
                <div className="sidebar-logo-icon">
                    <Zap size={20} color="white" />
                </div>
                <div className="sidebar-logo-text">
                    <h1>AfyaLinks</h1>
                    <p>Admin Portal</p>
                </div>
            </div>

            {/* Navigation */}
            <nav className="sidebar-nav">
                {sections.map(section => {
                    const items = NAV_ITEMS.filter(i => i.section === section.key);
                    return (
                        <div key={section.key}>
                            <div className="sidebar-nav-label">{section.label}</div>
                            {items.map(item => (
                                <NavLink
                                    key={item.path}
                                    to={item.path}
                                    end={item.path === '/'}
                                    className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
                                >
                                    <item.icon size={17} />
                                    {item.label}
                                </NavLink>
                            ))}
                        </div>
                    );
                })}
            </nav>

            {/* Footer */}
            <div className="sidebar-footer">
                <div className="sidebar-admin-info">
                    <div className="admin-avatar">A</div>
                    <div style={{ flex: 1, overflow: 'hidden' }}>
                        <div style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-primary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>Admin</div>
                        <div style={{ fontSize: '0.72rem', color: 'var(--text-secondary)' }}>Super Admin</div>
                    </div>
                    <div className="status-dot" title="System Online" />
                </div>
                <button className="sidebar-footer-btn" onClick={logout}>
                    <LogOut size={16} />
                    Sign Out
                </button>
            </div>
        </aside>
    );
};

const Topbar = () => {
    const location = useLocation();
    const [time, setTime] = useState(new Date());

    useEffect(() => {
        const timer = setInterval(() => setTime(new Date()), 1000);
        return () => clearInterval(timer);
    }, []);

    const pageInfo = PAGE_TITLES[location.pathname] ?? { title: 'Admin', subtitle: '' };

    const formatTime = (d: Date) =>
        d.toLocaleTimeString('en-UG', { hour: '2-digit', minute: '2-digit', hour12: true }) + ' · ' +
        d.toLocaleDateString('en-UG', { weekday: 'short', month: 'short', day: 'numeric' });

    return (
        <header className="topbar">
            <div className="topbar-left">
                <span className="topbar-title">{pageInfo.title}</span>
                <span className="topbar-breadcrumb">{pageInfo.subtitle}</span>
            </div>

            <div className="search-bar" style={{ flex: 1, maxWidth: '400px', margin: '0 2rem' }}>
                <Bell size={14} color="var(--text-secondary)" />
                <input
                    placeholder="Search for orders, users, or drivers..."
                    style={{ background: 'transparent', border: 'none', outline: 'none', width: '100%', color: 'white', fontSize: '0.85rem' }}
                />
            </div>

            <div className="topbar-right">
                <span className="topbar-time">{formatTime(time)}</span>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                    <Activity size={14} color="var(--status-success)" />
                    <span style={{ fontSize: '0.78rem', color: 'var(--status-success)', fontWeight: 500 }}>Online</span>
                </div>
            </div>
        </header>
    );
};

export const AppLayout = () => {
    return (
        <div className="app-layout">
            <Sidebar />
            <div className="main-wrapper">
                <Topbar />
                <main className="main-content fade-in">
                    <Outlet />
                </main>
            </div>
        </div>
    );
};
