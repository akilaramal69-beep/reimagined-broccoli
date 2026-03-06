# YouTube Video Downloader API

A REST API for downloading YouTube videos using yt-dlp with EJS templating. Deployable on Koyeb with Docker.

## Features

- Get video information
- List available formats/qualities
- Download videos in various formats
- Extract audio from videos
- Get subtitles/captions
- Playlist support
- Web UI for easy downloading
- Telegram bot integration ready

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/info?url=<URL>` | Get video info |
| GET | `/api/formats?url=<URL>` | Get available formats |
| GET | `/api/download?url=<URL>&formatId=<FORMAT>` | Download video |
| POST | `/api/download` | Download with JSON body |
| GET | `/api/audio?url=<URL>` | Extract audio only |
| GET | `/api/subtitles?url=<URL>` | Get available subtitles |
| GET | `/api/playlist?url=<URL>` | Get playlist info |
| GET | `/api/search?query=<QUERY>` | Search videos |
| GET | `/health` | Health check |

## API Examples

### Get Video Info
```bash
curl "http://localhost:8080/api/info?url=https://youtube.com/watch?v=xxxx"
```

### Get Formats
```bash
curl "http://localhost:8080/api/formats?url=https://youtube.com/watch?v=xxxx"
```

### Download Video
```bash
# Best quality
curl -J "http://localhost:8080/api/download?url=https://youtube.com/watch?v=xxxx"

# Specific format
curl -J "http://localhost:8080/api/download?url=https://youtube.com/watch?v=xxxx&formatId=18"
```

### Extract Audio
```bash
curl -J "http://localhost:8080/api/audio?url=https://youtube.com/watch?v=xxxx"
```

### Get Subtitles
```bash
curl "http://localhost:8080/api/subtitlesyoutube.com/watch?v?url=https://=xxxx"
```

### Search
```bash
curl "http://localhost:8080/api/search?query=python tutorial"
```

## Quick Start (Local)

```bash
# Install dependencies
npm install

# Run the server
npm start
```

Visit `http://localhost:8080` for the web UI.

## Docker

```bash
# Build and run
docker build -t youtube-api .
docker run -p 8080:8080 youtube-api

# Or use docker-compose
docker-compose up -d
```

## Deploy to Koyeb

1. Push your code to GitHub
2. Create a new app on Koyeb
3. Select **Docker** as the service type
4. Set the following:
   - **Port**: 8080
   - **Builder**: Dockerfile
5. Deploy!

## Integration with Telegram Bot

To integrate with your Telegram bot at `https://github.com/akilaramal69-beep/reimagined-broccoli`:

Update your bot's environment variables:

```
LINK_API_URL=https://your-koyeb-app.koyeb.app
```

Or use this API directly in your bot code:

```python
import requests

def get_video_info(url):
    api_url = "https://your-koyeb-app.koyeb.app/api/formats"
    response = requests.get(api_url, params={"url": url})
    return response.json()
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| PORT | 8080 | Server port |
| API_URL | localhost:8080 | Public API URL |
| YTDLP_PATH | yt-dlp | Path to yt-dlp binary |

## Supported Platforms

yt-dlp supports 1700+ sites including:
- YouTube
- Instagram
- TikTok
- Twitter/X
- Facebook
- Reddit
- Vimeo
- And many more...

## Format IDs

Common format IDs for YouTube:
- `best` - Best quality (video+audio)
- `bestvideo+bestaudio` - Best video + best audio
- `worst` - Worst quality
- `18` - 360p MP4
- `22` - 720p MP4
- `137` - 1080p video only
- `140` - audio only (m4a)
- `251` - audio only (webm)

## Project Structure

```
youtube-downloader-api/
├── server.js          # Main API server
├── views/
│   └── index.ejs      # Web UI
├── public/            # Static files
├── downloads/         # Downloaded files
├── Dockerfile         # Docker config
├── docker-compose.yml
├── package.json
└── README.md
```
