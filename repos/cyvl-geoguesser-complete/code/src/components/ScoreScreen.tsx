import { useParams, useNavigate, useLocation } from 'react-router-dom';
import Map, { Marker, Source, Layer } from 'react-map-gl/mapbox';
import * as turf from '@turf/turf';
import type { Round } from '../types/api';
import 'mapbox-gl/dist/mapbox-gl.css';

export default function ScoreScreen() {
  const { gameId } = useParams<{ gameId: string }>();
  const navigate = useNavigate();
  const location = useLocation();
  
  const { round, isLastRound, scoreFromLastRound, totalCurrentScore } = location.state as {
    round: Round;
    isLastRound: boolean;
    scoreFromLastRound?: number;
    totalCurrentScore?: number;
  };

  const mapboxToken = import.meta.env.VITE_MAPBOX_TOKEN;

  if (!round || !round.actual_location || !round.guess_location) {
    return (
      <div className="w-screen h-screen flex flex-col items-center justify-center gap-5 bg-[#0c0c0c] text-[#fffffe]">
        <h2 className="m-0 text-3xl">Error</h2>
        <p className="m-0 text-base">Round data not available</p>
        <button 
          onClick={() => navigate('/')}
          className="px-6 py-3 text-base text-[#0c0c0c] bg-[#dbff00] border-none rounded-lg cursor-pointer transition-all hover:brightness-110"
        >
          Back to Home
        </button>
      </div>
    );
  }

  const handleNextClick = () => {
    if (isLastRound) {
      navigate(`/game/${gameId}/results`);
    } else {
      navigate(`/game/${gameId}`);
    }
  };

  // Calculate bounds to fit both markers
  const bounds = {
    longitude: (round.actual_location.longitude + round.guess_location.longitude) / 2,
    latitude: (round.actual_location.latitude + round.guess_location.latitude) / 2,
    zoom: 2,
  };

  // Create a great circle route between the two points (handles antimeridian correctly)
  const from = turf.point([round.guess_location.longitude, round.guess_location.latitude]);
  const to = turf.point([round.actual_location.longitude, round.actual_location.latitude]);
  const greatCircle = turf.greatCircle(from, to, { npoints: 100 });
  
  const lineGeoJSON = greatCircle;

  return (
    <div className="w-screen h-screen relative overflow-hidden">
      <div className="absolute top-0 left-0 right-0 p-10 bg-gradient-to-b from-[#0c0c0c]/90 to-transparent z-[1000] pointer-events-none">
        <div className="flex flex-col items-center gap-5 pointer-events-auto">
          <h1 className="m-0 text-4xl font-bold text-[#fffffe] drop-shadow-lg">Round Score</h1>
          <div className="text-7xl font-bold text-[#dbff00] drop-shadow-lg">
            {scoreFromLastRound !== undefined ? scoreFromLastRound : round.score}
          </div>
          {totalCurrentScore !== undefined && (
            <div className="text-xl text-[#fffffe]/80 drop-shadow-lg">
              Total Score: {totalCurrentScore}
            </div>
          )}
          <button 
            className="px-8 py-3.5 text-lg font-semibold text-[#0c0c0c] bg-[#dbff00] border-none rounded-xl cursor-pointer shadow-lg shadow-[#dbff00]/40 transition-all hover:brightness-110 hover:-translate-y-0.5 hover:shadow-xl hover:shadow-[#dbff00]/60 active:translate-y-0"
            onClick={handleNextClick}
          >
            {isLastRound ? 'View Results' : 'Next Round'}
          </button>
        </div>
      </div>

      {mapboxToken ? (
        <Map
          mapboxAccessToken={mapboxToken}
          initialViewState={bounds}
          style={{ width: '100%', height: '100%' }}
          mapStyle="mapbox://styles/mapbox/streets-v12"
        >
          {/* Line connecting the points */}
          <Source id="route" type="geojson" data={lineGeoJSON}>
            <Layer
              id="route-line"
              type="line"
              paint={{
                'line-color': '#667eea',
                'line-width': 3,
                'line-dasharray': [2, 2],
              }}
            />
          </Source>

          {/* Actual location marker (green) */}
          <Marker
            longitude={round.actual_location.longitude}
            latitude={round.actual_location.latitude}
            anchor="bottom"
          >
            <div className="text-4xl drop-shadow-md hue-rotate-90">📍</div>
          </Marker>

          {/* Guess location marker (red) */}
          <Marker
            longitude={round.guess_location.longitude}
            latitude={round.guess_location.latitude}
            anchor="bottom"
          >
            <div className="text-4xl drop-shadow-md -hue-rotate-30">📍</div>
          </Marker>
        </Map>
      ) : (
        <div className="w-screen h-screen flex items-center justify-center bg-[#0c0c0c] text-[#fffffe]">
          Mapbox token not configured
        </div>
      )}
    </div>
  );
}

