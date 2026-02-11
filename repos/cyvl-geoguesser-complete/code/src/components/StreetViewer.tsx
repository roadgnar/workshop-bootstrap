interface StreetViewerProps {
  imageUrl: string;
}

export default function StreetViewer({ imageUrl }: StreetViewerProps) {
  return (
    <div className="w-full h-full relative">
      <iframe
        src={imageUrl}
        className="w-full h-full border-none block"
        title="360° Street View"
        allow="fullscreen"
        loading="lazy"
      />
    </div>
  );
}

