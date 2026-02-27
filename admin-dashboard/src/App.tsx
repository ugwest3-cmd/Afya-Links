import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { AppLayout } from './components/Layout';
import { Login } from './pages/Login';
import { Dashboard } from './pages/Dashboard';
import { Verifications } from './pages/Verifications';
import { Users } from './pages/Users';

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
        <Route path="orders" element={<div className="p-6 text-h2 text-muted fade-in">Orders Module (Coming Soon)</div>} />
        <Route path="invoices" element={<div className="p-6 text-h2 text-muted fade-in">Invoices Module (Coming Soon)</div>} />
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
