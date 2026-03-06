import { useEffect, useRef } from 'react';
import api from '../lib/api';

export const useGeolocation = (isActive: boolean) => {
    const watchId = useRef<number | null>(null);

    useEffect(() => {
        if (!isActive) {
            if (watchId.current !== null) {
                navigator.geolocation.clearWatch(watchId.current);
                watchId.current = null;
            }
            return;
        }

        if (!("geolocation" in navigator)) {
            console.error("Geolocation not supported");
            return;
        }

        watchId.current = navigator.geolocation.watchPosition(
            async (position) => {
                const { latitude, longitude } = position.coords;
                try {
                    await api.post('/tracking/update', { latitude, longitude });
                } catch (err) {
                    console.error("Failed to update location", err);
                }
            },
            (error) => {
                console.error("Geolocation error", error);
            },
            {
                enableHighAccuracy: true,
                timeout: 5000,
                maximumAge: 0,
            }
        );

        return () => {
            if (watchId.current !== null) {
                navigator.geolocation.clearWatch(watchId.current);
            }
        };
    }, [isActive]);
};
