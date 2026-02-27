import app from './app';
import dotenv from 'dotenv';
import { initCronJobs } from './utils/cronJobs';

dotenv.config();

const PORT = process.env.PORT || 5000;

// Initialize Cron Jobs
initCronJobs();

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
