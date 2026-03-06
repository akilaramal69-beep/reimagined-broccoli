FROM python:3.11-slim

# Install system dependencies including Node.js and Playwright requirements
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ffmpeg \
    aria2 \
    git \
    gcc \
    python3-dev \
    curl \
    ca-certificates \
    gnupg \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libdbus-1-3 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2 \
    libatspi2.0-0 \
    fonts-unifont \
    fonts-liberation \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install Playwright browsers
RUN playwright install chromium || true

# Copy project files
COPY . .

# Install Node.js dependencies for the root (PO Token Server)
RUN if [ -f package.json ]; then \
    npm install; \
    else \
    npm init -y && npm install express youtube-po-token-generator; \
    fi

# Install Node.js dependencies for youtube_api
RUN cd youtube_api && npm install

# Create downloads directories
RUN mkdir -p DOWNLOADS youtube_api/downloads

# Set environment variables
ENV FFMPEG_PATH=/usr/bin/ffmpeg
ENV YOUTUBE_API_URL=http://localhost:8001
ENV PORT=8080

# Make start script executable and fix Windows line endings
RUN chmod +x start.sh && sed -i 's/\r$//' start.sh

# Koyeb expects a web service to listen on port 8080 (the bot's health server)
EXPOSE 8080

# Use the startup script to launch all processes
CMD ["./start.sh"]
