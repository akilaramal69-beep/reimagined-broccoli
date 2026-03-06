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
RUN printf "require('dotenv').config();\n\
    const express = require('express');\n\
    const { exec, spawn } = require('child_process');\n\
    const fs = require('fs-extra');\n\
    const path = require('path');\n\
    const cors = require('cors');\n\
    const axios = require('axios');\n\
    \n\
    const app = express();\n\
    const PORT = process.env.PORT || 8080;\n\
    \n\
    app.use(cors());\n\
    app.use(express.json());\n\
    app.use(express.urlencoded({ extended: true }));\n\
    app.set('view engine', 'ejs');\n\
    app.set('views', path.join(__dirname, 'views'));\n\
    app.use(express.static('public'));\n\
    \n\
    const DOWNLOAD_DIR = path.join(__dirname, 'downloads');\n\
    fs.ensureDirSync(DOWNLOAD_DIR);\n\
    \n\
    function getYtdlpCommand() {\n\
    return process.env.YTDLP_PATH || 'yt-dlp';\n\
    }\n\
    \n\
    async function getPoToken() {\n\
    try {\n\
    const res = await axios.get('http://localhost:4416/', { timeout: 30000 });\n\
    return res.data;\n\
    } catch (e) {\n\
    console.error(\"PO Token Fetch Failed (Optional):\", e.message);\n\
    return null;\n\
    }\n\
    }\n\
    \n\
    async function getVideoInfo(url) {\n\
    const po = await getPoToken();\n\
    let poArgs = \"\";\n\
    if (po && po.poToken && po.visitorData) {\n\
    poArgs = \` --extractor-args \"youtube:po_token=web+\${po.poToken};visitor_data=\${po.visitorData}\"\`;\n\
    }\n\
    return new Promise((resolve, reject) => {\n\
    const cmd = \`\"\${getYtdlpCommand()}\" --dump-json --no-download --impersonate chrome\${poArgs} \"\${url}\"\`;\n\
    exec(cmd, { maxBuffer: 50 * 1024 * 1024 }, (error, stdout, stderr) => {\n\
    if (error) {\n\
    reject(error);\n\
    return;\n\
    }\n\
    try {\n\
    const info = JSON.parse(stdout);\n\
    resolve(info);\n\
    } catch (e) {\n\
    reject(e);\n\
    }\n\
    });\n\
    });\n\
    }\n\
    \n\
    async function getFormats(url) {\n\
    const po = await getPoToken();\n\
    let poArgs = \"\";\n\
    if (po && po.poToken && po.visitorData) {\n\
    poArgs = \` --extractor-args \"youtube:po_token=web+\${po.poToken};visitor_data=\${po.visitorData}\"\`;\n\
    }\n\
    return new Promise((resolve, reject) => {\n\
    const cmd = \`\"\${getYtdlpCommand()}\" --dump-json --no-download --flat --impersonate chrome\${poArgs} \"\${url}\"\`;\n\
    exec(cmd, { maxBuffer: 50 * 1024 * 1024 }, (error, stdout, stderr) => {\n\
    if (error) {\n\
    reject(error);\n\
    return;\n\
    }\n\
    try {\n\
    const info = JSON.parse(stdout);\n\
    const formats = info.formats || [];\n\
    const filtered = formats.map(f => ({\n\
    format_id: f.format_id,\n\
    ext: f.ext,\n\
    resolution: f.resolution || 'audio only',\n\
    filesize: f.filesize,\n\
    fmt_note: f.format_note,\n\
    vcodec: f.vcodec,\n\
    acodec: f.acodec\n\
    })).filter(f => f.ext === 'mp4' || f.ext === 'webm' || f.ext === 'm4a');\n\
    resolve({\n\
    title: info.title,\n\
    thumbnail: info.thumbnail,\n\
    duration: info.duration,\n\
    uploader: info.uploader,\n\
    formats: filtered\n\
    });\n\
    } catch (e) {\n\
    reject(e);\n\
    }\n\
    });\n\
    });\n\
    }\n\
    \n\
    async function downloadVideo(url, formatId, res) {\n\
    const filename = \`video_\${Date.now()}\`;\n\
    const outputPath = path.join(DOWNLOAD_DIR, '%%(title)s.%%(ext)s');\n\
    \n\
    const po = await getPoToken();\n\
    \n\
    return new Promise((resolve, reject) => {\n\
    const args = [\n\
    '--impersonate', 'chrome',\n\
    '-f', formatId || 'best',\n\
    '-o', outputPath,\n\
    '--no-playlist',\n\
    '--no-warnings',\n\
    '--progress'\n\
    ];\n\
    \n\
    if (po && po.poToken && po.visitorData) {\n\
    args.push('--extractor-args', \`youtube:po_token=web+\${po.poToken};visitor_data=\${po.visitorData}\`);\n\
    }\n\
    \n\
    args.push(url);\n\
    \n\
    const proc = spawn(getYtdlpCommand(), args);\n\
    let stderr = '';\n\
    \n\
    proc.stderr.on('data', (data) => {\n\
    stderr += data.toString();\n\
    const progressMatch = data.toString().match(/(\\\\d+\\\\.?\\\\d*)%%/);\n\
    if (progressMatch && res) {\n\
    res.write(\`data: \${progressMatch[1]}\\n\\n\`);\n\
    }\n\
    });\n\
    \n\
    proc.on('close', (code) => {\n\
    if (code === 0) {\n\
    const files = fs.readdirSync(DOWNLOAD_DIR);\n\
    const downloadedFile = files.find(f => f.startsWith('video_') || f.includes('.'));\n\
    if (downloadedFile) {\n\
    resolve(path.join(DOWNLOAD_DIR, downloadedFile));\n\
    } else {\n\
    reject(new Error('Download failed'));\n\
    }\n\
    } else {\n\
    reject(new Error(stderr || 'Download failed'));\n\
    }\n\
    });\n\
    \n\
    proc.on('error', reject);\n\
    });\n\
    }\n\
    \n\
    app.get('/', (req, res) => {\n\
    res.render('index', {\n\
    title: 'YouTube Downloader API',\n\
    apiUrl: process.env.API_URL || \`http://localhost:\${PORT}\` \n\
    });\n\
    });\n\
    \n\
    app.get('/api/info', async (req, res) => {\n\
    try {\n\
    const { url } = req.query;\n\
    if (!url) {\n\
    return res.status(400).json({ error: 'URL is required' });\n\
    }\n\
    const info = await getVideoInfo(url);\n\
    res.json({\n\
    title: info.title,\n\
    thumbnail: info.thumbnail,\n\
    duration: info.duration,\n\
    uploader: info.uploader,\n\
    description: info.description,\n\
    view_count: info.view_count,\n\
    upload_date: info.upload_date\n\
    });\n\
    } catch (error) {\n\
    res.status(500).json({ error: error.message });\n\
    }\n\
    });\n\
    \n\
    app.get('/api/formats', async (req, res) => {\n\
    try {\n\
    const { url } = req.query;\n\
    if (!url) {\n\
    return res.status(400).json({ error: 'URL is required' });\n\
    }\n\
    const formats = await getFormats(url);\n\
    res.json(formats);\n\
    } catch (error) {\n\
    res.status(500).json({ error: error.message });\n\
    }\n\
    });\n\
    \n\
    app.post('/api/download', async (req, res) => {\n\
    try {\n\
    const { url, formatId } = req.body;\n\
    if (!url) {\n\
    return res.status(400).json({ error: 'URL is required' });\n\
    }\n\
    \n\
    const filePath = await downloadVideo(url, formatId, null);\n\
    \n\
    res.download(filePath, path.basename(filePath), (err) => {\n\
    if (err) console.error('Download error:', err);\n\
    fs.remove(filePath).catch(() => { });\n\
    });\n\
    \n\
    } catch (error) {\n\
    res.status(500).json({ error: error.message });\n\
    }\n\
    });\n\
    \n\
    app.get('/api/download', async (req, res) => {\n\
    try {\n\
    const { url, formatId } = req.query;\n\
    if (!url) {\n\
    return res.status(400).json({ error: 'URL is required' });\n\
    }\n\
    \n\
    const filePath = await downloadVideo(url, formatId, null);\n\
    \n\
    res.download(filePath, path.basename(filePath), (err) => {\n\
    if (err) console.error('Download error:', err);\n\
    fs.remove(filePath).catch(() => { });\n\
    });\n\
    \n\
    } catch (error) {\n\
    res.status(500).json({ error: error.message });\n\
    }\n\
    });\n\
    \n\
    app.get('/health', (req, res) => {\n\
    res.json({ status: 'ok', timestamp: new Date().toISOString() });\n\
    });\n\
    \n\
    app.use((err, req, res, next) => {\n\
    console.error(err.stack);\n\
    res.status(500).json({ error: 'Internal server error' });\n\
    });\n\
    \n\
    app.listen(PORT, '0.0.0.0', () => {\n\
    console.log(\`YouTube Downloader API running on port \${PORT}\`);\n\
    console.log(\`Health check: http://localhost:\${PORT}/health\`);\n\
    });\n\
    \n\
    process.on('SIGTERM', () => {\n\
    console.log('Cleaning up...');\n\
    fs.remove(DOWNLOAD_DIR).catch(() => { });\n\
    process.exit(0);\n\
    });" > youtube_api/server.js && cd youtube_api && npm install

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
