import { useState, useCallback } from 'react';
import Map, { Marker } from 'react-map-gl/mapbox';
import 'mapbox-gl/dist/mapbox-gl.css';
import type { Location } from '../types/api';

interface MiniMapProps {
  onGuess: (location: Location) => void;
}

export default function MiniMap({ onGuess }: MiniMapProps) {
  const [pinLocation, setPinLocation] = useState<Location | null>(null);

  const mapboxToken = import.meta.env.VITE_MAPBOX_TOKEN;

  const handleMapClick = useCallback((event: any) => {
    const { lngLat } = event;
    setPinLocation({
      latitude: lngLat.lat,
      longitude: lngLat.lng,
    });
  }, []);

  const handleGuessClick = useCallback(() => {
    if (pinLocation) {
      onGuess(pinLocation);
    }
  }, [pinLocation, onGuess]);

  if (!mapboxToken) {
    return (
      <div className="fixed bottom-5 right-5 px-5 py-3 bg-red-500/90 text-white rounded-lg text-sm">
        Mapbox token not configured
      </div>
    );
  }

  return (
    <div className="fixed bottom-5 right-5 w-[400px] h-[300px] rounded-xl overflow-hidden shadow-2xl z-[1000] [&_.mapboxgl-canvas]:cursor-pointer [&_.mapboxgl-canvas:active]:cursor-grabbing">
      <Map
        mapboxAccessToken={mapboxToken}
        initialViewState={{
          longitude: 0,
          latitude: 20,
          zoom: 1,
        }}
        style={{ width: '100%', height: '100%' }}
        mapStyle="mapbox://styles/mapbox/streets-v12"
        onClick={handleMapClick}
      >
        {pinLocation && (
          <Marker
            longitude={pinLocation.longitude}
            latitude={pinLocation.latitude}
            anchor="bottom"
          >
            <div className="text-[32px] cursor-pointer drop-shadow-md">📍</div>
          </Marker>
        )}
      </Map>

      {pinLocation && (
        <button
          className="absolute bottom-3 left-1/2 -translate-x-1/2 px-6 py-2.5 text-base font-semibold text-[#0c0c0c] bg-[#dbff00] border-none rounded-lg cursor-pointer shadow-md z-10 transition-all hover:brightness-110 hover:-translate-y-0.5 hover:-translate-x-1/2 hover:shadow-lg active:translate-y-0 active:-translate-x-1/2"
          onClick={handleGuessClick}
        >
          Guess
        </button>
      )}
    </div>
  );
}

