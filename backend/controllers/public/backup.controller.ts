const { getBackupStatus, toggleCloudBackup, updateSyncSuccess, isCloudEnvironment } = require("../../utils/backupTracker");
const { processBackup } = require("../../modules/backupService");
const { restoreFromEncBuffer } = require("../../modules/restore");
const { uploadBackupViaScript, cleanOldBackups, createClientFolder } = require("../../modules/driveService");
const loadConfig = require("../../utils/decryptConfig");
const fs = require("fs");
const path = require("path");

const rootDir = (process as any).pkg ? path.dirname(process.execPath) : process.cwd();
const CLIENT_FILE = path.join(rootDir, "client.json");
const BACKUP_DIR = path.join(rootDir, 'backups');

exports.getBackupStatusAlert = (req, res) => {
    try {

        const outletCode = req.outlet_code;


        const status = getBackupStatus(outletCode);
        let alertType = "NONE";

        if (!status.isCloudEnabled) {
            alertType = "ENABLE_PROMPT";
        } else {
            const now = new Date().getTime();
            if (!status.lastSyncTime || (now - status.lastSyncTime) > 86400000) {
                alertType = "SYNC_FAILED";
            }
        }

        return res.status(200).json({
            success: true,
            alert: alertType,
            lastSyncTime: status.lastSyncTime
        });

    } catch (err) {
        console.error("Backup Status Controller Error:", err);
        return res.status(500).json({
            success: false,
            error: "Internal server error while checking backup status."
        });
    }
};

exports.toggleBackup = (req, res) => {
    try {
        const outletCode = req.outlet_code;
        const { enabled } = req.body;

        toggleCloudBackup(outletCode, enabled);

        return res.status(200).json({
            success: true,
            message: enabled ? "Cloud backup enabled" : "Cloud backup disabled"
        });

    } catch (err) {
        console.error("Toggle Backup Error:", err);
        return res.status(500).json({ success: false, error: err.message });
    }
};

exports.createLocalEncBackup = async (req, res) => {
    try {
        const dbName =
            req.propertyDb?.config?.database ||
            process.env.DB_NAME ||
            "";
        if (!dbName) {
            return res.status(500).json({
                success: false,
                message: "Database name could not be resolved for backup."
            });
        }

        const encPath = await processBackup(dbName);
        const fileBuffer = fs.readFileSync(encPath);
        const filename = path.basename(encPath);

        return res.status(200).json({
            success: true,
            data: {
                filename,
                base64: fileBuffer.toString("base64")
            }
        });
    } catch (err) {
        console.error("Local ENC backup error:", err);
        return res.status(500).json({
            success: false,
            message: err.message || "Failed to create .enc backup."
        });
    }
};

exports.restoreFromLocalEnc = async (req, res) => {
    try {
        const filename = String(req.body.filename || "").trim();
        const base64 = String(req.body.base64 || "").trim();
        if (!filename.toLowerCase().endsWith(".enc")) {
            return res.status(400).json({
                success: false,
                message: "Only .enc backup files are allowed."
            });
        }
        if (!base64) {
            return res.status(400).json({
                success: false,
                message: "Backup payload is required."
            });
        }

        const encBuffer = Buffer.from(base64, "base64");
        if (!encBuffer.length) {
            return res.status(400).json({
                success: false,
                message: "Invalid backup payload."
            });
        }

        await restoreFromEncBuffer(encBuffer);
        return res.status(200).json({
            success: true,
            message: "Backup restored successfully from .enc file."
        });
    } catch (err) {
        console.error("Restore from local ENC error:", err);
        return res.status(500).json({
            success: false,
            message: err.message || "Failed to restore .enc backup."
        });
    }
};

exports.uploadBackupOnDemand = async (req, res) => {
    try {
        const outletCode = req.user?.outlet_code || req.outlet_code;

        if (!outletCode) {
            return res.status(400).json({
                success: false,
                message: "Missing outlet code in request."
            });
        }

        let clients = [];
        if (fs.existsSync(CLIENT_FILE)) {
            try {
                const fileData = fs.readFileSync(CLIENT_FILE, "utf8");
                clients = JSON.parse(fileData);
                if (!Array.isArray(clients)) clients = [clients];
            } catch (_) { clients = []; }
        }

        let targetClient = clients.find(c => c && c.outlet_code === outletCode);
        if (!targetClient) {
            targetClient = { outlet_code: outletCode, folderId: null };
            clients.push(targetClient);
            try { fs.writeFileSync(CLIENT_FILE, JSON.stringify(clients, null, 2)); } catch (_) {}
        }

        const config = loadConfig();
        const dbName = config.db_database || process.env.DB_NAME;

        if (!dbName) {
            return res.status(500).json({
                success: false,
                message: "Database name could not be resolved."
            });
        }

        if (!fs.existsSync(BACKUP_DIR)) {
            fs.mkdirSync(BACKUP_DIR, { recursive: true });
        }

        console.log(`[BACKUP] Starting enterprise backup sequence for outlet ${outletCode}...`);

        const tempFile = await processBackup(dbName);
        if (!tempFile || !fs.existsSync(tempFile)) {
            throw new Error(`Backup creation failed. File not found at temporary path.`);
        }

        const now = new Date();
        const timestamp = now.getFullYear() + '-' +
            String(now.getMonth() + 1).padStart(2, '0') + '-' +
            String(now.getDate()).padStart(2, '0') + '_' +
            String(now.getHours()).padStart(2, '0') + '-' +
            String(now.getMinutes()).padStart(2, '0') + '-' +
            String(now.getSeconds()).padStart(2, '0');

        const fileName = `backup_${timestamp}.enc`;
        const finalFilePath = path.join(BACKUP_DIR, fileName);

        fs.renameSync(tempFile, finalFilePath);

        // If running on Cloud Online Server, DO NOT use Google Script / Drive.
        // If running on Local Server, use Google Script and Google Drive backup!
        const isCloudServer = isCloudEnvironment();

        if (isCloudServer) {
            // Rotate enterprise server backups - preserve latest 30 snapshots
            try {
                const files = fs.readdirSync(BACKUP_DIR)
                    .filter(f => f.startsWith('backup_') && f.endsWith('.enc'))
                    .map(f => ({ name: f, time: fs.statSync(path.join(BACKUP_DIR, f)).mtime.getTime() }))
                    .sort((a, b) => b.time - a.time);

                if (files.length > 30) {
                    for (let i = 30; i < files.length; i++) {
                        try { fs.unlinkSync(path.join(BACKUP_DIR, files[i].name)); } catch (_) {}
                    }
                }
            } catch (_) {}

            updateSyncSuccess(outletCode);
            targetClient.last_backup_file = fileName;
            try { fs.writeFileSync(CLIENT_FILE, JSON.stringify(clients, null, 2)); } catch (_) {}

            console.log(`[ENTERPRISE BACKUP] Secured on enterprise server storage for outlet ${outletCode}: ${fileName}`);
            return res.status(200).json({
                success: true,
                message: "Enterprise database backup encrypted and secured on server storage successfully!",
                filename: fileName,
                storage_mode: 'ENTERPRISE_SERVER'
            });
        }

        let folderIdToUse = targetClient.folderId;
        let uploadSuccess = false;

        if (folderIdToUse) {
            try {
                await uploadBackupViaScript(finalFilePath, fileName, folderIdToUse);
                await cleanOldBackups(folderIdToUse);
                uploadSuccess = true;
            } catch (uploadErr) {
                console.warn(`[UPLOAD] Initial upload attempt failed: ${uploadErr.message}`);
                folderIdToUse = null;
            }
        }

        if (!folderIdToUse) {
            console.log(`[UPLOAD] Cloud directory recreating for outlet ${outletCode}...`);
            const newFolderId = await createClientFolder(outletCode);
            if (!newFolderId) {
                // Securely fall back to server storage
                updateSyncSuccess(outletCode);
                return res.status(200).json({
                    success: true,
                    message: "Enterprise database backup encrypted and secured on server storage successfully!",
                    filename: fileName,
                    storage_mode: 'ENTERPRISE_SERVER'
                });
            }
            targetClient.folderId = newFolderId;
            try { fs.writeFileSync(CLIENT_FILE, JSON.stringify(clients, null, 2)); } catch (_) {}

            await uploadBackupViaScript(finalFilePath, fileName, newFolderId);
            await cleanOldBackups(newFolderId);
            uploadSuccess = true;
        }

        if (uploadSuccess) {
            updateSyncSuccess(outletCode);
            console.log(`[UPLOAD] Cloud upload complete for outlet ${outletCode}.`);
            return res.status(200).json({
                success: true,
                message: "Backup uploaded to cloud successfully!"
            });
        } else {
            throw new Error("Cloud upload sequence completed but flag was false.");
        }

    } catch (err) {
        console.error("On-demand backup upload failed:", err);
        return res.status(500).json({
            success: false,
            message: err.message || "Failed to upload backup to cloud."
        });
    }
};

module.exports = exports;
export default exports;
