const express = require('express');
const { generate } = require('youtube-po-token-generator');

const app = express();
const PORT = 4416;

let cachedToken = null;
let isGenerating = false;
let lastGenerationTime = 0;
const CACHE_DURATION = 30 * 60 * 1000; // 30 minutes

async function rotateToken() {
    if (isGenerating) return;
    isGenerating = true;
    console.log(`[${new Date().toISOString()}] PO Token: Starting background generation...`);

    try {
        // We set a strict timeout for the generator itself to prevent hang-ups
        const result = await Promise.race([
            generate(),
            new Promise((_, reject) => setTimeout(() => reject(new Error('Generator Timeout')), 60000))
        ]);

        cachedToken = {
            visitorData: result.visitorData,
            poToken: result.poToken,
            generatedAt: new Date().toISOString()
        };
        lastGenerationTime = Date.now();
        console.log(`[${new Date().toISOString()}] PO Token: Update successful.`);
    } catch (error) {
        console.error(`[${new Date().toISOString()}] PO Token: Update failed:`, error.message);
    } finally {
        isGenerating = false;
        // Clean up global state if possible (Node garbage collection hint)
        if (global.gc) global.gc();
    }
}

// Initial generation
rotateToken();

// Auto-rotate every 30 minutes
const rotationInterval = setInterval(rotateToken, CACHE_DURATION);

app.get('/', (req, res) => {
    // If we have a token (even if it's getting old), return it immediately for performance
    if (cachedToken) {
        // Trigger background refresh if older than 25 mins
        if (!isGenerating && (Date.now() - lastGenerationTime > (CACHE_DURATION - 5 * 60 * 1000))) {
            rotateToken();
        }
        return res.json(cachedToken);
    }

    // If no token is ready yet (e.g., first few seconds of boot)
    if (isGenerating) {
        return res.status(503).json({
            error: "Initial PO Token generation in progress. Please retry in 10 seconds.",
            retryAfter: 10
        });
    }

    res.status(500).json({ error: "PO Token generation failed. Check server logs." });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`PO Token Server running on http://localhost:${PORT}`);
    console.log(`Memory limit is being managed via --max-old-space-size in start.sh`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    clearInterval(rotationInterval);
    process.exit(0);
});
