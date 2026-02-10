import { useNavigate } from 'react-router-dom';

// TODO: Implement the Score Screen — see SRS Section 3.4 (UI-030 through UI-034)
//
// This component should:
// 1. Read round result data from React Router's location state (passed from GuessScreen)
//    - Expected state: { round, isLastRound, scoreFromLastRound, totalCurrentScore }
// 2. Display the round score prominently in a top overlay
// 3. Show the total cumulative score
// 4. Render a full-screen interactive map showing:
//    a. A marker at the actual location (visually distinct)
//    b. A marker at the guessed location (visually distinct)
//    c. A dashed great-circle line connecting the two points
// 5. Provide a "Next Round" button (or "View Results" if last round)
//
// Available packages (already in package.json):
// - react-map-gl/mapbox — for the map component and markers
// - @turf/turf — for computing the great-circle route
// - mapbox-gl — required peer dependency (import the CSS: 'mapbox-gl/dist/mapbox-gl.css')
//
// Map token: import.meta.env.VITE_MAPBOX_TOKEN
//
// Refer to existing components for styling patterns:
// - MiniMap.tsx — for Mapbox map + marker usage
// - ResultsScreen.tsx — for score display and navigation patterns
// - GuessScreen.tsx — for loading/error state patterns
// - SRS Section 3.1 — for the design system (colors, buttons, typography)

export default function ScoreScreen() {
  const navigate = useNavigate();

  return (
    <div className="w-screen h-screen flex flex-col items-center justify-center gap-5 bg-[#0c0c0c] text-[#fffffe]">
      <h2 className="m-0 text-3xl">Score Screen</h2>
      <p className="m-0 text-base text-[#fffffe]/60">
        This screen is not yet implemented.
      </p>
      <p className="m-0 text-sm text-[#fffffe]/40">
        See SRS Section 3.4 for requirements.
      </p>
      <button 
        onClick={() => navigate('/')}
        className="px-6 py-3 text-base text-[#0c0c0c] bg-[#dbff00] border-none rounded-lg cursor-pointer transition-all hover:brightness-110"
      >
        Back to Home
      </button>
    </div>
  );
}
