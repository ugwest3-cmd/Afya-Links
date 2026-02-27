import express, { Express, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';

const app: Express = express();

// Middlewares
app.use(helmet());
app.use(cors());
app.use(morgan('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

import authRoutes from './routes/auth.routes';
import userRoutes from './routes/user.routes';
import pharmacyRoutes from './routes/pharmacy.routes';
import clinicRoutes from './routes/clinic.routes';
import adminRoutes from './routes/admin.routes';
import ussdRoutes from './routes/ussd.routes';

// Health Check Endpoint
app.get('/health', (req: Request, res: Response) => {
  res.status(200).json({ status: 'ok', message: 'Afya Links API is running' });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/pharmacies', pharmacyRoutes);
app.use('/api/clinics', clinicRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/ussd', ussdRoutes);

// Error Handling Middleware
app.use((err: any, req: Request, res: Response, next: NextFunction) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal Server Error'
  });
});

export default app;
