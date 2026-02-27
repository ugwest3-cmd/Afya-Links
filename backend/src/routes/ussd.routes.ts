import { Router } from 'express';
import { handleUSSD } from '../controllers/ussd.controller';

const router = Router();

// AT sends POST request to this endpoint
router.post('/callback', handleUSSD);

export default router;
