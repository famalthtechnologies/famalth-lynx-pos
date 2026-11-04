"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.retry = retry;
async function retry(fn, retries = 3, delay = 3000) {
    let attempt = 0;
    while (attempt < retries) {
        try {
            return await fn();
        }
        catch (err) {
            attempt++;
            console.log(`❌ Attempt ${attempt} failed`);
            if (attempt >= retries)
                throw err;
            await new Promise(res => setTimeout(res, delay));
        }
    }
    throw new Error('Retry limit reached');
}
exports.default = { retry };
