"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.zipAndEncrypt = zipAndEncrypt;
const archiver = require("archiver");
const crypto_1 = __importDefault(require("crypto"));
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const ALGORITHM = "aes-256-cbc";
const SECRET = process.env.BACKUP_SECRET || "my_super_secret_key";
const isCompiled = typeof process.pkg !== "undefined";
const baseDir = isCompiled ? path_1.default.dirname(process.execPath) : path_1.default.join(__dirname, "..");
function getKey() {
    return crypto_1.default.createHash("sha256").update(SECRET).digest();
}
function zipAndEncrypt(inputFile, backupStem) {
    return new Promise((resolve, reject) => {
        try {
            const stem = backupStem || path_1.default.basename(inputFile, path_1.default.extname(inputFile));
            const zipFile = path_1.default.join(baseDir, "backups", `${stem}.zip`);
            const encFile = path_1.default.join(baseDir, "backups", `${stem}.enc`);
            const output = fs_1.default.createWriteStream(zipFile);
            const archive = archiver("zip", { zlib: { level: 9 } });
            archive.on("error", reject);
            output.on("error", reject);
            output.on("close", () => {
                try {
                    const key = getKey();
                    const iv = crypto_1.default.randomBytes(16);
                    const cipher = crypto_1.default.createCipheriv(ALGORITHM, key, iv);
                    const input = fs_1.default.createReadStream(zipFile);
                    const out = fs_1.default.createWriteStream(encFile);
                    out.on("error", reject);
                    input.on("error", reject);
                    out.write(iv);
                    input
                        .pipe(cipher)
                        .pipe(out)
                        .on("finish", () => {
                        console.log("🔐 Backup encrypted successfully");
                        fs_1.default.unlink(zipFile, () => { });
                        resolve(encFile);
                    })
                        .on("error", reject);
                }
                catch (err) {
                    reject(err);
                }
            });
            archive.pipe(output);
            archive.file(inputFile, { name: "backup.sql" });
            archive.finalize();
        }
        catch (err) {
            reject(err);
        }
    });
}
exports.default = { zipAndEncrypt };
