const fsSync = require("fs");
const path = require("path");
const { execSync } = require("child_process");

function findPostgresBinary(binaryName) {
    const exeName = process.platform === "win32" ? `${binaryName}.exe` : binaryName;

    if (process.platform === "win32") {
        const isCompiled = typeof process.pkg !== "undefined";
        const appDir = isCompiled ? path.dirname(process.execPath) : path.join(__dirname, "..");
        const configuredCandidates = [];

        // 1. Process environment variable
        const configuredBin = process.env.FAMALTH_PG_BIN;
        if (configuredBin) configuredCandidates.push(configuredBin.trim().replace(/^"|"$/g, ""));

        // 2. pg_bin.txt in app directory
        try {
            const savedBin = fsSync.readFileSync(path.join(appDir, "pg_bin.txt"), "utf8").trim();
            if (savedBin) configuredCandidates.push(savedBin.replace(/^"|"$/g, ""));
        } catch (_) {}

        // 3. Dynamic scan for any PostgreSQL version (25 down to 10) in appDir and root directories
        for (let ver = 25; ver >= 10; ver--) {
            configuredCandidates.push(
                path.join(appDir, `PostgreSQL${ver}`, "bin"),
                `C:\\FamalthLynx\\PostgreSQL${ver}\\bin`,
                `D:\\FamalthLynx\\PostgreSQL${ver}\\bin`
            );
        }
        configuredCandidates.push(
            path.join(appDir, "PostgreSQL", "bin"),
            "C:\\FamalthLynx\\PostgreSQL\\bin",
            "D:\\FamalthLynx\\PostgreSQL\\bin"
        );

        for (const binDir of configuredCandidates) {
            if (binDir) {
                const candidate = path.join(binDir, exeName);
                if (fsSync.existsSync(candidate)) return candidate;
            }
        }
    }

    // 4. Try finding in system PATH
    try {
        const cmd = process.platform === "win32" ? `where.exe ${exeName}` : `which ${binaryName}`;
        const output = execSync(cmd, { stdio: ["pipe", "pipe", "ignore"], encoding: "utf8" });
        const firstLine = output.split(/\r?\n/)[0]?.trim();
        if (firstLine && fsSync.existsSync(firstLine)) {
            return firstLine;
        }
    } catch (_) {}

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
                const candidate = path.join(base, "PostgreSQL", String(ver), "bin", exeName);
                if (fsSync.existsSync(candidate)) {
                    return candidate;
                }
            }
        }
    }

    // 6. Fallback to binary name
    return binaryName;
}

module.exports = { findPostgresBinary };
