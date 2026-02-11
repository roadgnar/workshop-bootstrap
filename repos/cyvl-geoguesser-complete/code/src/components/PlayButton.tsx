import { ButtonHTMLAttributes } from 'react';

interface PlayButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  text?: string;
  loading?: boolean;
}

export default function PlayButton({ 
  text = 'Play', 
  loading = false,
  disabled,
  ...props 
}: PlayButtonProps) {
  return (
    <button
      className="px-12 py-4 text-2xl font-semibold text-[#0c0c0c] bg-[#dbff00] border-none rounded-xl cursor-pointer transition-all duration-300 shadow-lg shadow-[#dbff00]/40 hover:shadow-xl hover:shadow-[#dbff00]/60 hover:-translate-y-0.5 hover:brightness-110 active:translate-y-0 disabled:opacity-60 disabled:cursor-not-allowed"
      disabled={disabled || loading}
      {...props}
    >
      {loading ? 'Loading...' : text}
    </button>
  );
}

