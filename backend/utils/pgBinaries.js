"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.findPostgresBinary = findPostgresBinary;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const child_process_1 = require("child_process");
function findPostgresBinary(binaryName) {
    const exeName = process.platform === "win32" ? `${binaryName}.exe` : binaryName;
    if (process.platform === "win32") {
        const isCompiled = typeof process.pkg !== "undefined";
        const appDir = isCompiled ? path_1.default.dirname(process.execPath) : path_1.default.join(__dirname, "..");
        const configuredCandidates = [];
        // 1. Process environment variable
        const configuredBin = process.env.FAMALTH_PG_BIN;
        if (configuredBin)
            configuredCandidates.push(configuredBin.trim().replace(/^"|"$/g, ""));
        // 2. pg_bin.txt in app directory
        try {
            const savedBin = fs_1.default.readFileSync(path_1.default.join(appDir, "pg_bin.txt"), "utf8").trim();
            if (savedBin)
                configuredCandidates.push(savedBin.replace(/^"|"$/g, ""));
        }
        catch (_) { }
        // 3. Dynamic scan for any PostgreSQL version (25 down to 10) in appDir and root directories
        for (let ver = 25; ver >= 10; ver--) {
            configuredCandidates.push(path_1.default.join(appDir, `PostgreSQL${ver}`, "bin"), `C:\\FamalthLynx\\PostgreSQL${ver}\\bin`, `D:\\FamalthLynx\\PostgreSQL${ver}\\bin`);
        }
        configuredCandidates.push(path_1.default.join(appDir, "PostgreSQL", "bin"), "C:\\FamalthLynx\\PostgreSQL\\bin", "D:\\FamalthLynx\\PostgreSQL\\bin");
        for (const binDir of configuredCandidates) {
            if (binDir) {
                const candidate = path_1.default.join(binDir, exeName);
                if (fs_1.default.existsSync(candidate))
                    return candidate;
            }
        }
    }
    // 4. Try finding in system PATH
    try {
        const cmd = process.platform === "win32" ? `where.exe ${exeName}` : `which ${binaryName}`;
        const output = (0, child_process_1.execSync)(cmd, { stdio: ["pipe", "pipe", "ignore"], encoding: "utf8" });
        const firstLine = output.split(/\r?\n/)[0]?.trim();
        if (firstLine && fs_1.default.existsSync(firstLine)) {
            return firstLine;
        }
    }
    catch (_) { }
    // 5. Try known Windows Program Files directories for versions 20 down to 10
    if (process.platform === "win32") {
        const basePaths = [
            process.env.ProgramFiles || "C:\\Program Files",
            process.env["ProgramFiles(x86)"] || "C:\\Program Files (x86)",
            "C:\\PostgreSQL",
            "D:\\PostgreSQL"
        ];
        for (let ver = 20; ver >= 10; ver--) {
            for (const base of basePaths) {
                const candidate = path_1.default.join(base, "PostgreSQL", String(ver), "bin", exeName);
                if (fs_1.default.existsSync(candidate)) {
                    return candidate;
                }
            }
        }
    }
    // 6. Fallback to binary name
    return binaryName;
}
exports.default = { findPostgresBinary };
