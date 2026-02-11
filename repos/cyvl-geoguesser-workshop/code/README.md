# CYVL GeoGuesser

An in-house version of the popular game "GeoGuessr" using our own 360 imagery

## Setup

Install dependencies:

```sh
task install
```

Create a `.env.local` file in the root directory, add your Mapbox token:
```
VITE_MAPBOX_TOKEN=your_mapbox_token_here
```

## Development

Start the frontend development server:
```sh
task frontend:dev
```

Start the backend API server:
```sh
task api:dev
```