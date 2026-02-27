import { useEffect, useState } from 'react';
import api from '../utils/api';
import { UserPlus, Search, Phone, ShieldCheck, UserX } from 'lucide-react';

interface User {
    id: string;
    name: string | null;
    email: string | null;
    phone: string;
    role: string;
    is_verified: boolean;
    created_at: string;
}

export const Users = () => {
    const [users, setUsers] = useState<User[]>([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');

    // Modal state
    const [showModal, setShowModal] = useState(false);
    const [newPhone, setNewPhone] = useState('');
    const [newName, setNewName] = useState('');
    const [newRole, setNewRole] = useState('CLINIC');
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState('');

    const fetchUsers = async () => {
        try {
            const res = await api.get('/admin/users');
            if (res.data.success) {
                setUsers(res.data.users || []);
            }
        } catch (e) {
            console.error(e);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchUsers();
    }, []);

    const handleAddUser = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setSaving(true);
        try {
            const res = await api.post('/admin/users', { phone: newPhone, name: newName, role: newRole });
            if (res.data.success) {
                setUsers([res.data.user, ...users]);
                setShowModal(false);
                setNewPhone('');
                setNewName('');
            }
        } catch (e: any) {
            console.error(e);
            setError(e.response?.data?.message || 'Failed to add user');
        } finally {
            setSaving(false);
        }
    };

    const filteredUsers = users.filter(u =>
        (u.name?.toLowerCase().includes(search.toLowerCase()) || '') ||
        u.phone.includes(search) ||
        u.role.toLowerCase().includes(search.toLowerCase())
    );

    return (
        <div className="fade-in" style={{ maxWidth: '1200px', margin: '0 auto' }}>
            <header style={{ marginBottom: '2rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
                <div>
                    <h1 className="text-h2">Users Management</h1>
                    <p className="text-muted">Manage Pharmacies, Clinics, Drivers, and other users.</p>
                </div>
                <button
                    onClick={() => setShowModal(true)}
                    className="btn-primary"
                    style={{ display: 'flex', alignItems: 'center', gap: '8px' }}
                >
                    <UserPlus size={18} /> Add New User
                </button>
            </header>

            <div className="glass-panel" style={{ padding: '1rem', marginBottom: '1.5rem', display: 'flex', gap: '1rem', alignItems: 'center' }}>
                <Search size={20} style={{ color: 'var(--text-muted)' }} />
                <input
                    type="text"
                    placeholder="Search by name, phone, or role..."
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    style={{ background: 'transparent', border: 'none', color: 'var(--text-primary)', width: '100%', outline: 'none', fontSize: '1rem' }}
                />
            </div>

            {loading ? (
                <div style={{ textAlign: 'center', padding: '3rem', color: 'var(--text-secondary)' }}>Loading users...</div>
            ) : (
                <div className="glass-panel" style={{ overflow: 'hidden' }}>
                    <div style={{ overflowX: 'auto' }}>
                        <table className="data-table">
                            <thead>
                                <tr>
                                    <th>Date Added</th>
                                    <th>Name</th>
                                    <th>Phone</th>
                                    <th>Role</th>
                                    <th>Status</th>
                                </tr>
                            </thead>
                            <tbody>
                                {filteredUsers.length === 0 ? (
                                    <tr>
                                        <td colSpan={5} style={{ textAlign: 'center', padding: '2rem' }}>No users found.</td>
                                    </tr>
                                ) : filteredUsers.map(user => (
                                    <tr key={user.id}>
                                        <td>{new Date(user.created_at).toLocaleDateString()}</td>
                                        <td style={{ fontWeight: 500 }}>{user.name || '—'}</td>
                                        <td>
                                            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                                                <Phone size={14} style={{ opacity: 0.6 }} /> {user.phone}
                                            </div>
                                        </td>
                                        <td>
                                            <span className={`badge ${user.role === 'ADMIN' ? 'badge-info' : 'badge-primary'}`}>
                                                {user.role}
                                            </span>
                                        </td>
                                        <td>
                                            {user.is_verified ? (
                                                <span style={{ color: 'var(--status-success)', display: 'flex', alignItems: 'center', gap: '4px', fontSize: '0.875rem', fontWeight: 500 }}>
                                                    <ShieldCheck size={16} /> Verified
                                                </span>
                                            ) : (
                                                <span style={{ color: 'var(--status-warning)', display: 'flex', alignItems: 'center', gap: '4px', fontSize: '0.875rem', fontWeight: 500 }}>
                                                    <UserX size={16} /> Pending
                                                </span>
                                            )}
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </div>
            )}

            {/* Add User Modal */}
            {showModal && (
                <div style={{
                    position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
                    background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(4px)',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    zIndex: 100, padding: '1rem'
                }}>
                    <div className="glass-panel fade-in" style={{ width: '100%', maxWidth: '450px', padding: '2rem' }}>
                        <h2 className="text-h3" style={{ marginBottom: '1.5rem' }}>Add New User</h2>

                        {error && (
                            <div style={{ background: 'rgba(239, 68, 68, 0.15)', color: 'var(--status-danger)', padding: '0.75rem 1rem', borderRadius: '8px', marginBottom: '1.5rem', fontSize: '0.875rem' }}>
                                {error}
                            </div>
                        )}

                        <form onSubmit={handleAddUser} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                            <div>
                                <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.875rem', color: 'var(--text-secondary)' }}>Role</label>
                                <select
                                    className="input-base"
                                    value={newRole}
                                    onChange={(e) => setNewRole(e.target.value)}
                                    style={{ width: '100%' }}
                                >
                                    <option value="CLINIC">Clinic / Drug Shop</option>
                                    <option value="PHARMACY">Pharmacy</option>
                                    <option value="DRIVER">Driver</option>
                                    <option value="ADMIN">Admin</option>
                                </select>
                            </div>

                            <div>
                                <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.875rem', color: 'var(--text-secondary)' }}>Phone Number (Required for Login)</label>
                                <input
                                    type="tel"
                                    className="input-base"
                                    placeholder="+256700000000"
                                    required
                                    value={newPhone}
                                    onChange={(e) => setNewPhone(e.target.value)}
                                    style={{ width: '100%' }}
                                />
                            </div>

                            <div>
                                <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.875rem', color: 'var(--text-secondary)' }}>Business / Person Name</label>
                                <input
                                    type="text"
                                    className="input-base"
                                    placeholder="E.g. Good Health Clinic"
                                    value={newName}
                                    onChange={(e) => setNewName(e.target.value)}
                                    style={{ width: '100%' }}
                                />
                            </div>

                            <div style={{ display: 'flex', gap: '1rem', marginTop: '1rem' }}>
                                <button
                                    type="button"
                                    className="btn-secondary"
                                    style={{ flex: 1 }}
                                    onClick={() => setShowModal(false)}
                                    disabled={saving}
                                >
                                    Cancel
                                </button>
                                <button
                                    type="submit"
                                    className="btn-primary"
                                    style={{ flex: 1 }}
                                    disabled={saving}
                                >
                                    {saving ? 'Saving...' : 'Create User'}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
};
