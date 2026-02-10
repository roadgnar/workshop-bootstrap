import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import StreetViewer from './StreetViewer';
import MiniMap from './MiniMap';
import { getGame, submitGuess } from '../services/api';
import type { Game, Round, Location } from '../types/api';

export default function GuessScreen() {
  const { gameId } = useParams<{ gameId: string }>();
  const navigate = useNavigate();
  
  const [game, setGame] = useState<Game | null>(null);
  const [currentRound, setCurrentRound] = useState<Round | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (!gameId) {
      setError('No game ID provided');
      setLoading(false);
      return;
    }

    loadGame(gameId);
  }, [gameId]);

  const loadGame = async (id: string) => {
    try {
      setLoading(true);
      setError(null);
      const gameData = await getGame(id);
      setGame(gameData);

      // Find the current round
      const round = gameData.rounds.find(r => r.id === gameData.current_round_id);
      if (!round) {
        throw new Error('Current round not found');
      }
      setCurrentRound(round);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load game');
    } finally {
      setLoading(false);
    }
  };

  const handleGuess = async (location: Location) => {
    if (!currentRound || !gameId) return;

    try {
      setSubmitting(true);
      await submitGuess(currentRound.id, location);

      // Navigate to score screen
      const roundIndex = game?.current_round_index ?? 0;
      navigate(`/game/${gameId}/score/${roundIndex}`);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to submit guess');
      setSubmitting(false);
    }
  };

  if (loading) {
    return (
      <div className="w-screen h-screen flex flex-col items-center justify-center gap-5 bg-[#0c0c0c] text-[#fffffe]">
        <div className="w-12 h-12 border-4 border-[#dbff00]/30 border-t-[#dbff00] rounded-full animate-spin"></div>
        <p>Loading game...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="w-screen h-screen flex flex-col items-center justify-center gap-5 bg-[#0c0c0c] text-[#fffffe]">
        <h2 className="m-0 text-3xl">Error</h2>
        <p className="m-0 text-base text-red-400">{error}</p>
        <button 
          onClick={() => navigate('/')}
          className="px-6 py-3 text-base text-[#0c0c0c] bg-[#dbff00] border-none rounded-lg cursor-pointer transition-all hover:brightness-110"
        >
          Back to Home
        </button>
      </div>
    );
  }

  if (!currentRound) {
    return (
      <div className="w-screen h-screen flex flex-col items-center justify-center gap-5 bg-[#0c0c0c] text-[#fffffe]">
        <h2 className="m-0 text-3xl">No Round Available</h2>
        <button 
          onClick={() => navigate('/')}
          className="px-6 py-3 text-base text-[#0c0c0c] bg-[#dbff00] border-none rounded-lg cursor-pointer transition-all hover:brightness-110"
        >
          Back to Home
        </button>
      </div>
    );
  }

  return (
    <div className="w-screen h-screen relative overflow-hidden">
      <StreetViewer imageUrl={currentRound.image_url} />
      <MiniMap onGuess={handleGuess} />
      
      {submitting && (
        <div className="fixed top-0 left-0 w-screen h-screen bg-black/70 flex flex-col items-center justify-center gap-5 z-[2000] text-[#fffffe] text-lg">
          <div className="w-12 h-12 border-4 border-[#dbff00]/30 border-t-[#dbff00] rounded-full animate-spin"></div>
          <p>Submitting guess...</p>
        </div>
      )}
    </div>
  );
}

