# API

## Models

Location:
- latitude: float
- longitude: float

Round
- id: UUID
- image_url: url
- actual_location: Location
- guess_location: Location
- score: int

## Endpoints

### POST - `/game/create`

Request:
```json
{}
```

Response:

```json
{
    "id": UUID
}
```

### GET - `/game/{game_id}`

```json
{
    "current_round_id": UUID,
    "current_round_index": int,
    "rounds": Round[]
}
```

### POST - `/guess/{round_id}`

Request:
```json
{
    "guess_location": Location
}
```

Response:
```json
{
    "round": Round,
    "is_last_round": bool
}
```