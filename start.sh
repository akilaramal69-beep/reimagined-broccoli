#!/bin/bash

echo "🚀 Starting PO Token Server on port 4416..."
node po_server.js &

echo "🚀 Starting YouTube Downloader API on port 8001..."
# We set PORT=8001 for the internal API to avoid conflict with Bot Health Server (8080)
PORT=8001 node youtube_api/server.js &

echo "🚀 Starting URL Uploader Bot and Health Server (8080)..."
python3 bot.py
