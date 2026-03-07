import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { AppLayout } from './components/Layout';
import { Login } from './pages/Login';
import { Dashboard } from './pages/Dashboard';
import { Verifications } from './pages/Verifications';
import { Users } from './pages/Users';
import { Orders } from './pages/Orders';
import { Drivers } from './pages/Drivers';
import { LiveMap } from './pages/LiveMap';
import { Notifications } from './pages/Notifications';
import { Invoices } from './pages/Invoices';
import { Escrow } from './pages/Escrow';
import { Payouts } from './pages/Payouts';
import { Settings } from './pages/Settings';

const ProtectedRoute = ({ children }: { children: React.ReactNode }) => {
  const { user, loading } = useAuth();

  if (loading) return null;
  if (!user || user.role !== 'ADMIN') return <Navigate to="/login" replace />;

  return <>{children}</>;
};

const AppRoutes = () => {
  const { user, loading } = useAuth();

  if (loading) return null;

  return (
    <Routes>
      <Route path="/login" element={user && user.role === 'ADMIN' ? <Navigate to="/" replace /> : <Login />} />

      <Route path="/" element={<ProtectedRoute><AppLayout /></ProtectedRoute>}>
        <Route index element={<Dashboard />} />
        <Route path="users" element={<Users />} />
        <Route path="verifications" element={<Verifications />} />
        <Route path="map" element={<LiveMap />} />
        <Route path="orders" element={<Orders />} />
        <Route path="drivers" element={<Drivers />} />
        <Route path="notifications" element={<Notifications />} />
        <Route path="invoices" element={<Invoices />} />
        <Route path="escrow" element={<Escrow />} />
        <Route path="payouts" element={<Payouts />} />
        <Route path="settings" element={<Settings />} />
      </Route>
    </Routes>
  );
};

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <AppRoutes />
      </BrowserRouter>
    </AuthProvider>
  );
}

export default App;
