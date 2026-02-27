import axios from 'axios';

const api = axios.create({
    baseURL: 'http://localhost:5000/api', // Will match the running backend
});

api.interceptors.request.use((config) => {
    const token = localStorage.getItem('afyalinks_admin_token');
    if (token) {
        config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
});

export default api;
