const fs = require("fs");
const path = require("path");
const { sendToGoogleScript } = require("./driveService");
const rootDir = process.pkg ? path.dirname(process.execPath) : process.cwd();
const CONFIG_ENC_PATH = path.join(rootDir, "config.enc");
const CLIENT_JSON_PATH = path.join(rootDir, "client.json");

/**
 * Uploads both config.enc and client.json to Google Drive.
 * Safely overwrites the previous versions in the cloud.
 */
async function uploadSystemConfigs(folderId) {
    try {
        console.log("[CONFIG_SYNC] Synchronizing system configurations to Google Drive...");

        // 1. Upload config.enc
        const candidateConfigPaths = [
            path.join(rootDir, "config.enc"),
            path.join(rootDir, "backend", "config.enc"),
            path.join(process.cwd(), "config.enc"),
            path.join(process.cwd(), "backend", "config.enc")
        ];
        const configEncPath = candidateConfigPaths.find(p => fs.existsSync(p));

        if (configEncPath) {
            const encBase64 = fs.readFileSync(configEncPath).toString('base64');
            await sendToGoogleScript({
                action: 'upload_config',
                folderId: folderId,
                filename: "config.enc",
                mimeType: "application/octet-stream",
                base64: encBase64
            });
            console.log("[CONFIG_SYNC] config.enc synced successfully to Google Drive.");
        } else {
            console.log("[CONFIG_SYNC] config.enc not found locally. Skipping upload.");
        }

        // 2. Upload client.json
        const candidateClientPaths = [
            path.join(rootDir, "client.json"),
            path.join(rootDir, "backend", "client.json"),
            path.join(process.cwd(), "client.json"),
            path.join(process.cwd(), "backend", "client.json")
        ];
        const clientJsonPath = candidateClientPaths.find(p => fs.existsSync(p));

        if (clientJsonPath) {
            const jsonBase64 = fs.readFileSync(clientJsonPath).toString('base64');
            await sendToGoogleScript({
                action: 'upload_config',
                folderId: folderId,
                filename: "client.json",
                mimeType: "application/json",
                base64: jsonBase64
            });
            console.log("[CONFIG_SYNC] client.json synced successfully to Google Drive.");
        } else {
            console.log("[CONFIG_SYNC] client.json not found locally. Skipping upload.");
        }

        // 3. Upload license.key
        const candidateLicensePaths = [
            path.join(rootDir, "license.key"),
            path.join(rootDir, "backend", "license.key"),
            path.join(process.cwd(), "license.key"),
            path.join(process.cwd(), "backend", "license.key")
        ];
        const licensePath = candidateLicensePaths.find(p => fs.existsSync(p));

        if (licensePath) {
            const licBase64 = fs.readFileSync(licensePath).toString('base64');
            await sendToGoogleScript({
                action: 'upload_config',
                folderId: folderId,
                filename: "license.key",
                mimeType: "application/json",
                base64: licBase64
            });
            console.log("[CONFIG_SYNC] license.key synced successfully to Google Drive.");
        } else {
            const defaultLicense = {
                license_id: `LIC-${folderId.substring(0, 8)}`,
                valid_till: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
                allowed_mode: "HYBRID",
                modules: ["INVENTORY", "PURCHASE", "SUPPLIER", "REPORTS", "ADMIN"]
            };
            const licBase64 = Buffer.from(JSON.stringify(defaultLicense, null, 2)).toString('base64');
            await sendToGoogleScript({
                action: 'upload_config',
                folderId: folderId,
                filename: "license.key",
                mimeType: "application/json",
                base64: licBase64
            });
            console.log("[CONFIG_SYNC] Generated license.key synced successfully to Google Drive.");
        }

    } catch (error) {
        console.error(`[CONFIG_SYNC] Failed to upload configurations: ${error.message}`);
    }
}

/**
 * Downloads client.json (and optionally config.enc) from Google Drive.
 * It intelligently merges the downloaded client.json array with the local array
 * to ensure multi-outlet configurations are preserved.
 */
async function downloadSystemConfigs(folderId) {
    try {
        console.log("[CONFIG_SYNC] Restoring system configurations from cloud...");

        // Download client.json
        try {
            const resJson = await sendToGoogleScript({
                action: 'download_config',
                folderId: folderId,
                filename: "client.json"
            });

            const downloadedContent = Buffer.from(resJson.base64, 'base64').toString('utf8');
            let downloadedClients = JSON.parse(downloadedContent);

            if (!Array.isArray(downloadedClients)) {
                downloadedClients = [downloadedClients];
            }

            // Merge logic: If local client.json exists, merge the downloaded clients into it.
            let localClients = [];
            if (fs.existsSync(CLIENT_JSON_PATH)) {
                try {
                    const localContent = fs.readFileSync(CLIENT_JSON_PATH, 'utf8');
                    localClients = JSON.parse(localContent);
                    if (!Array.isArray(localClients)) {
                        localClients = [localClients];
                    }
                } catch (parseErr) {
                    console.error("[CONFIG_SYNC] Local client.json corrupted. Will overwrite entirely.");
                    localClients = [];
                }
            }

            // Upsert each downloaded client into the local array
            for (const downloadedClient of downloadedClients) {
                const existingIndex = localClients.findIndex(c => c.outlet_code === downloadedClient.outlet_code);
                if (existingIndex >= 0) {
                    localClients[existingIndex] = downloadedClient;
                } else {
                    localClients.push(downloadedClient);
                }
            }

            fs.writeFileSync(CLIENT_JSON_PATH, JSON.stringify(localClients, null, 2));
            console.log("[CONFIG_SYNC] client.json restored and merged successfully.");

        } catch (e) {
            console.log("[CONFIG_SYNC] Could not download client.json (It might not exist in the cloud yet).");
        }

        // (Optional) Uncomment to enable downloading config.enc
        /*
        try {
            const resEnc = await sendToGoogleScript({
                action: 'download_config',
                folderId: folderId,
                filename: "config.enc"
            });
            fs.writeFileSync(CONFIG_ENC_PATH, Buffer.from(resEnc.base64, 'base64'));
            console.log("[CONFIG_SYNC] config.enc restored.");
        } catch (e) {
            console.log("[CONFIG_SYNC] Could not download config.enc.");
        }
        */

    } catch (error) {
        console.error(`[CONFIG_SYNC] Failed during restore process: ${error.message}`);
        throw error;
    }
}

module.exports = {
    uploadSystemConfigs,
    downloadSystemConfigs
};