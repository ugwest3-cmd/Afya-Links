import app from './app';
import dotenv from 'dotenv';
import { initCronJobs } from './utils/cronJobs';

dotenv.config();

const PORT = parseInt(process.env.PORT || '5000', 10);
const HOST = '0.0.0.0'; // Required for Railway / Docker

// Initialize Cron Jobs
try {
    initCronJobs();
} catch (err) {
    console.error('Cron jobs failed to initialize (non-fatal):', err);
}

const server = app.listen(PORT, HOST, () => {
    console.log(`✅ Server is running on http://${HOST}:${PORT}`);
});

server.on('error', (err) => {
    console.error('❌ Server error:', err);
    process.exit(1);
});

process.on('unhandledRejection', (reason) => {
    console.error('Unhandled rejection:', reason);
});
