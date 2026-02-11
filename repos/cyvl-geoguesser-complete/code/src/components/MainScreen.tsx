import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import PlayButton from './PlayButton';
import { createGame } from '../services/api';

export default function MainScreen() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();

  const handlePlayClick = async () => {
    setLoading(true);
    setError(null);

    try {
      const response = await createGame();
      navigate(`/game/${response.id}`);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create game');
      setLoading(false);
    }
  };

  return (
    <div className="w-screen h-screen flex items-center justify-center bg-[#0c0c0c]">
      <div className="flex flex-col items-center gap-8">
        <div className="flex flex-col items-center gap-4">
          <img 
            src="/cyvl-logo.png" 
            alt="CYVL" 
            className="w-72 h-auto"
          />
          <h1 className="text-7xl font-bold text-[#fffffe] m-0">
            GeoGuesser
          </h1>
        </div>
        <PlayButton 
          text="Play" 
          loading={loading}
          onClick={handlePlayClick}
        />
        {error && (
          <p className="text-red-500 bg-[#fffffe] px-6 py-3 rounded-lg text-sm m-0">
            {error}
          </p>
        )}
      </div>
    </div>
  );
}

