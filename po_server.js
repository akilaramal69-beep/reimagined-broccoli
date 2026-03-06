const express = require('express');
const { generate } = require('youtube-po-token-generator');
const app = express();
const PORT = 4416;

app.get('/', async (req, res) => {
    try {
        console.log(`[${new Date().toISOString()}] Generating PO Token...`);

        // The generator can take time, but we don't want to hang forever
        const tokenPromise = generate();
        const timeoutPromise = new Promise((_, reject) =>
            setTimeout(() => reject(new Error('PO Token generation timed out')), 60000)
        );

        const { visitorData, poToken } = await Promise.race([tokenPromise, timeoutPromise]);

        console.log(`[${new Date().toISOString()}] Generated:`, { visitorData, poToken: poToken.substring(0, 10) + "..." });
        res.json({ visitorData, poToken });
    } catch (error) {
        console.error(`[${new Date().toISOString()}] Error:`, error.message);
        res.status(500).json({ error: error.message });
    }
});

app.listen(PORT, () => {
    console.log(`PO Token Server running on http://localhost:${PORT}`);
});
