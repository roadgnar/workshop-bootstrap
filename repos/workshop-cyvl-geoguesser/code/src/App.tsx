import { BrowserRouter, Routes, Route } from 'react-router-dom';
import MainScreen from './components/MainScreen';
import GuessScreen from './components/GuessScreen';
import ScoreScreen from './components/ScoreScreen';
import ResultsScreen from './components/ResultsScreen';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<MainScreen />} />
        <Route path="/game/:gameId" element={<GuessScreen />} />
        <Route path="/game/:gameId/score/:roundIndex" element={<ScoreScreen />} />
        <Route path="/game/:gameId/results" element={<ResultsScreen />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
