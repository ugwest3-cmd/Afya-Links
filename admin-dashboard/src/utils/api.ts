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

export default api;
