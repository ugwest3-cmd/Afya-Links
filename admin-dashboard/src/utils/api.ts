import axios from 'axios';

const api = axios.create({
    // Use HTTPS for production Railway domain
    baseURL: 'https://afya-links-production.up.railway.app/api',
});

api.interceptors.request.use((config) => {
    const token = localStorage.getItem('afyalinks_admin_token');
    if (token) {
        config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
});
api.interceptors.response.use(
    (response) => response,
    (error) => {
        if (error.response?.status === 401 && error.response?.data?.message?.includes('expired token')) {
            // Global handling for expired token
            localStorage.removeItem('afyalinks_admin_token');
            localStorage.removeItem('afyalinks_admin_user');
            window.location.href = '/login';
        }
        return Promise.reject(error);
    }
);

export default api;
