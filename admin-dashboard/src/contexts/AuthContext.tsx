import React, { createContext, useContext, useState, useEffect } from 'react';
import api from '../utils/api';

interface User {
    id: string;
    role: string;
}

interface AuthContextType {
    user: User | null;
    loading: boolean;
    login: (phone: string, otp: string) => Promise<boolean>;
    logout: () => void;
    requestOtp: (phone: string) => Promise<boolean>;
}

const AuthContext = createContext<AuthContextType | null>(null);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
    const [user, setUser] = useState<User | null>(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        // For MVP Admin, simply trust the token in localStorage to restore session
        const token = localStorage.getItem('afyalinks_admin_token');
        const role = localStorage.getItem('afyalinks_admin_role');

        if (token && role === 'ADMIN') {
            setUser({ id: 'admin', role: 'ADMIN' });
        }
        setLoading(false);
    }, []);

    const requestOtp = async (phone: string) => {
        try {
            await api.post('/auth/request-otp', { phone });
            return true;
        } catch (e) {
            console.error(e);
            return false;
        }
    };

    const login = async (phone: string, otp: string) => {
        try {
            const res = await api.post('/auth/verify-otp', { phone, otp, role: 'ADMIN' });
            if (res.data.success && res.data.user.role === 'ADMIN') {
                localStorage.setItem('afyalinks_admin_token', res.data.token);
                localStorage.setItem('afyalinks_admin_role', 'ADMIN');
                setUser({ id: res.data.user.id, role: 'ADMIN' });
                return true;
            }
            return false;
        } catch (e) {
            console.error(e);
            return false;
        }
    };

    const logout = () => {
        localStorage.removeItem('afyalinks_admin_token');
        localStorage.removeItem('afyalinks_admin_role');
        setUser(null);
    };

    return (
        <AuthContext.Provider value={{ user, loading, login, logout, requestOtp }}>
            {children}
        </AuthContext.Provider>
    );
};

export const useAuth = () => {
    const context = useContext(AuthContext);
    if (!context) throw new Error('useAuth must be used within an AuthProvider');
    return context;
};
