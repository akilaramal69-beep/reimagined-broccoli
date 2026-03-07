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
    && apt-get install -y nodejs unzip \
    && curl -fsSL https://deno.land/x/install/install.sh | sh \
    && rm -rf /var/lib/apt/lists/*

ENV DENO_INSTALL="/root/.deno"
ENV PATH="$DENO_INSTALL/bin:$PATH"

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install Playwright browsers
RUN playwright install chromium || true

# Copy project files
COPY . .

# Ensure youtube_api exists (clones if missing due to git issues)
RUN if [ ! -d "youtube_api" ]; then \
    git clone https://github.com/akilaramal69-beep/ytnew youtube_api; \
    fi

# Install Node.js dependencies for the root (PO Token Server)
RUN if [ -f package.json ]; then \
    npm install; \
    else \
    npm init -y && npm install express youtube-po-token-generator; \
    fi

# Apply fixes to youtube_api/server.js and install its dependencies
# Apply fixes to youtube_api/server.js and install its dependencies
RUN cat <<'EOF' > youtube_api/server.js
require('dotenv').config();
const express = require('express');
const { exec, spawn } = require('child_process');
const fs = require('fs-extra');
const path = require('path');
const cors = require('cors');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 8080;

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use(express.static('public'));

const DOWNLOAD_DIR = path.join(__dirname, 'downloads');
fs.ensureDirSync(DOWNLOAD_DIR);

function getYtdlpCommand() {
    return process.env.YTDLP_PATH || 'yt-dlp';
}

async function getPoToken() {
    try {
        const res = await axios.get('http://localhost:4416/', { timeout: 30000 });
        if (res.data && res.data.poToken) {
            return res.data;
        }
        return null;
    } catch (e) {
        console.error("PO Token Fetch Failed (Optional):", e.message);
        return null;
    }
}

function runYtdlp(args) {
    return new Promise((resolve, reject) => {
        const proc = spawn(getYtdlpCommand(), args);
        let stdout = '';
        let stderr = '';

        proc.stdout.on('data', (data) => stdout += data.toString());
        proc.stderr.on('data', (data) => stderr += data.toString());

        proc.on('close', (code) => {
            if (code === 0) {
                resolve({ stdout, stderr });
            } else {
                reject(new Error(stderr || `yt-dlp failed with code ${code}`));
            }
        });

        proc.on('error', (err) => {
            reject(new Error(`Spawn error: ${err.message}`));
        });
    });
}

async function getVideoInfo(url) {
    const po = await getPoToken();
    const args = ['--dump-json', '--no-download', '--impersonate', 'chrome', '--js-runtimes', 'deno'];
    if (po && po.poToken && po.visitorData) {
        args.push('--extractor-args', `youtube:po_token=web+${po.poToken};visitor_data=${po.visitorData}`);
    }
    args.push(url);

    const { stdout } = await runYtdlp(args);
    return JSON.parse(stdout);
}

async function getFormats(url) {
    const po = await getPoToken();
    const args = ['--dump-json', '--no-download', '--flat', '--impersonate', 'chrome', '--js-runtimes', 'deno'];
    if (po && po.poToken && po.visitorData) {
        args.push('--extractor-args', `youtube:po_token=web+${po.poToken};visitor_data=${po.visitorData}`);
    }
    args.push(url);

    const { stdout } = await runYtdlp(args);
    const info = JSON.parse(stdout);
    const formats = info.formats || [];
    const filtered = formats.map(f => ({
        format_id: f.format_id,
        ext: f.ext,
        resolution: f.resolution || 'audio only',
        filesize: f.filesize,
        fmt_note: f.format_note,
        vcodec: f.vcodec,
        acodec: f.acodec
    })).filter(f => f.ext === 'mp4' || f.ext === 'webm' || f.ext === 'm4a');

    return {
        title: info.title,
        thumbnail: info.thumbnail,
        duration: info.duration,
        uploader: info.uploader,
        formats: filtered
    };
}

async function downloadVideo(url, formatId, res) {
    const outputPath = path.join(DOWNLOAD_DIR, '%(title)s.%(ext)s');
    const po = await getPoToken();

    return new Promise((resolve, reject) => {
        const args = [
            '--impersonate', 'chrome',
            '--js-runtimes', 'deno',
            '-f', formatId || 'best',
            '-o', outputPath,
            '--no-playlist',
            '--no-warnings',
            '--progress'
        ];

        if (po && po.poToken && po.visitorData) {
            args.push('--extractor-args', `youtube:po_token=web+${po.poToken};visitor_data=${po.visitorData}`);
        }

        args.push(url);

        const proc = spawn(getYtdlpCommand(), args);
        let stderr = '';

        proc.stderr.on('data', (data) => {
            stderr += data.toString();
            const progressMatch = data.toString().match(/(\d+\.?\d*)%/);
            if (progressMatch && res) {
                res.write(`data: ${progressMatch[1]}\n\n`);
            }
        });

        proc.on('close', (code) => {
            if (code === 0) {
                const files = fs.readdirSync(DOWNLOAD_DIR);
                const downloadedFile = files.find(f => f.includes('.'));
                if (downloadedFile) {
                    resolve(path.join(DOWNLOAD_DIR, downloadedFile));
                } else {
                    reject(new Error('Download failed: file not found'));
                }
            } else {
                reject(new Error(stderr || `Download failed with code ${code}`));
            }
        });

        proc.on('error', reject);
    });
}

app.get('/', (req, res) => {
    res.render('index', {
        title: 'YouTube Downloader API',
        apiUrl: process.env.API_URL || `http://localhost:${PORT}`
    });
});

app.get('/api/version', async (req, res) => {
    try {
        const { stdout } = await runYtdlp(['--version']);
        res.json({ version: stdout.trim() });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/info', async (req, res) => {
    try {
        const { url } = req.query;
        if (!url) {
            return res.status(400).json({ error: 'URL is required' });
        }
        const info = await getVideoInfo(url);
        res.json({
            title: info.title,
            thumbnail: info.thumbnail,
            duration: info.duration,
            uploader: info.uploader,
            description: info.description,
            view_count: info.view_count,
            upload_date: info.upload_date
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/formats', async (req, res) => {
    try {
        const { url } = req.query;
        if (!url) {
            return res.status(400).json({ error: 'URL is required' });
        }
        const formats = await getFormats(url);
        res.json(formats);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/download', async (req, res) => {
    try {
        const { url, formatId } = req.body;
        if (!url) {
            return res.status(400).json({ error: 'URL is required' });
        }

        const filePath = await downloadVideo(url, formatId, null);

        res.download(filePath, path.basename(filePath), (err) => {
            if (err) console.error('Download error:', err);
            fs.remove(filePath).catch(() => { });
        });

    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/download', async (req, res) => {
    try {
        const { url, formatId } = req.query;
        if (!url) {
            return res.status(400).json({ error: 'URL is required' });
        }

        const filePath = await downloadVideo(url, formatId, null);

        res.download(filePath, path.basename(filePath), (err) => {
            if (err) console.error('Download error:', err);
            fs.remove(filePath).catch(() => { });
        });

    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ error: err.message || 'Internal server error' });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`YouTube Downloader API running on port ${PORT}`);
});

process.on('SIGTERM', () => {
    console.log('Cleaning up...');
    fs.remove(DOWNLOAD_DIR).catch(() => { });
    process.exit(0);
});
EOF
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
