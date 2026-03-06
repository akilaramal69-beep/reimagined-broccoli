FROM node:18-slim

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    ffmpeg \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --break-system-packages yt-dlp

WORKDIR /app

COPY package*.json ./
RUN npm install --production

COPY . .

RUN mkdir -p downloads

ENV PORT=8080
ENV NODE_ENV=production

EXPOSE 8080

CMD ["node", "server.js"]
