import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import PlayButton from './PlayButton';
import { getGame, createGame } from '../services/api';
import type { Game } from '../types/api';

export default function ResultsScreen() {
  const { gameId } = useParams<{ gameId: string }>();
  const navigate = useNavigate();
  
  const [game, setGame] = useState<Game | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [playingAgain, setPlayingAgain] = useState(false);

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
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load game');
    } finally {
      setLoading(false);
    }
  };

  const handlePlayAgain = async () => {
    try {
      setPlayingAgain(true);
      const response = await createGame();
      navigate(`/game/${response.id}`);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create game');
      setPlayingAgain(false);
    }
  };

  const calculateTotalScore = () => {
    if (!game) return 0;
    return game.rounds.reduce((total, round) => total + (round.score ?? 0), 0);
  };

  if (loading) {
    return (
      <div className="w-screen h-screen flex flex-col items-center justify-center gap-5 bg-[#0c0c0c] text-[#fffffe]">
        <div className="w-12 h-12 border-4 border-[#dbff00]/30 border-t-[#dbff00] rounded-full animate-spin"></div>
        <p>Loading results...</p>
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

  const totalScore = calculateTotalScore();

  return (
    <div className="w-screen h-screen flex items-center justify-center bg-[#0c0c0c]">
      <div className="flex flex-col items-center gap-8 p-10 max-w-2xl w-full">
        <h1 className="text-5xl font-bold text-[#fffffe] m-0 drop-shadow-lg">
          Game Complete!
        </h1>
        
        <div className="flex flex-col items-center gap-2 px-12 py-6 bg-[#fffffe]/10 rounded-2xl backdrop-blur-md shadow-lg shadow-black/20">
          <p className="text-lg text-[#fffffe]/80 m-0 font-medium">Final Score</p>
          <div className="text-8xl font-bold text-[#dbff00] drop-shadow-lg leading-none">
            {totalScore}
          </div>
        </div>

        <div className="w-full flex flex-col gap-4">
          <h2 className="text-2xl font-semibold text-[#fffffe] m-0 text-center">
            Round Breakdown
          </h2>
          <div className="flex flex-col gap-2">
            {game?.rounds.map((round, index) => (
              <div 
                key={round.id} 
                className="flex justify-between items-center px-5 py-3 bg-[#fffffe]/10 rounded-lg backdrop-blur-md"
              >
                <span className="text-base text-[#fffffe] font-medium">
                  Round {index + 1}
                </span>
                <span className="text-xl text-[#dbff00] font-semibold">
                  {round.score ?? 0}
                </span>
              </div>
            ))}
          </div>
        </div>

        <PlayButton 
          text="Play Again" 
          loading={playingAgain}
          onClick={handlePlayAgain}
        />
      </div>
    </div>
  );
}

