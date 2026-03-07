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
    console.log(`[${new Date().toISOString()}] Background Generation: Starting...`);

    try {
        const result = await generate();
        cachedToken = {
            visitorData: result.visitorData,
            poToken: result.poToken,
            generatedAt: new Date().toISOString()
        };
        lastGenerationTime = Date.now();
        console.log(`[${new Date().toISOString()}] Background Generation: Success!`);
    } catch (error) {
        console.error(`[${new Date().toISOString()}] Background Generation: Failed:`, error.message);
    } finally {
        isGenerating = false;
    }
}

// Initial generation
rotateToken();

// Auto-rotate every 30 minutes
setInterval(rotateToken, CACHE_DURATION);

app.get('/', async (req, res) => {
    if (!cachedToken) {
        // If we don't have a token yet, wait for the first generation if it's in progress
        if (isGenerating) {
            console.log(`[${new Date().toISOString()}] Request received: Generation in progress, waiting...`);
            let attempts = 0;
            while (isGenerating && attempts < 30) {
                await new Promise(r => setTimeout(r, 2000));
                attempts++;
            }
        }
    }

    if (cachedToken) {
        // If token is getting old (e.g. older than 25 mins), trigger an async refresh but return the old one for speed
        if (Date.now() - lastGenerationTime > (CACHE_DURATION - 5 * 60 * 1000)) {
            rotateToken();
        }
        return res.json(cachedToken);
    }

    res.status(503).json({ error: "PO Token generation in progress or failed. Please retry in a moment." });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`PO Token Server running on http://localhost:${PORT}`);
});
