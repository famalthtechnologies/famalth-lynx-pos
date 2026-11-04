"use strict";
const fs = require('fs');
const path = require('path');
const { extractSchemaFromMigrations } = require('../utils/migrationSchemaExtractor');
const migSchema = extractSchemaFromMigrations();
const migTables = new Map();
for (const t of migSchema.tables) {
    migTables.set(t.tableName.toLowerCase(), new Set(t.columns.map(c => c.name.toLowerCase())));
}
console.log(`Loaded ${migTables.size} tables from migrations.`);
const modelDirs = [
    path.join(__dirname, '../models/master'),
    path.join(__dirname, '../models/property')
];
const results = [];
for (const dir of modelDirs) {
    if (!fs.existsSync(dir))
        continue;
    const files = fs.readdirSync(dir).filter(f => f.endsWith('.model.js') || f.endsWith('.model.ts'));
    const baseNames = new Set(files.map(f => f.replace(/\.(js|ts)$/, '')));
    for (const base of baseNames) {
        const tsFile = path.join(dir, base + '.ts');
        const jsFile = path.join(dir, base + '.js');
        const fileToRead = fs.existsSync(tsFile) ? tsFile : jsFile;
        const content = fs.readFileSync(fileToRead, 'utf8');
        let tableNameMatch = content.match(/tableName:\s*['"]([^'"]+)['"]/);
        if (!tableNameMatch) {
            tableNameMatch = content.match(/sequelize\.define\(\s*['"]([^'"]+)['"]/);
        }
        if (!tableNameMatch)
            continue;
        const tableName = tableNameMatch[1].toLowerCase();
        const migCols = migTables.get(tableName);
        if (!migCols) {
            results.push({ type: 'MISSING_TABLE', table: tableName, file: path.basename(fileToRead) });
            continue;
        }
        // Try to extract columns from model definition
        const colRegex = /([a-zA-Z0-9_]+)\s*:\s*(?:\{[^}]*type\s*:\s*DataTypes|DataTypes\.)/g;
        let colMatch;
        const missingCols = [];
        while ((colMatch = colRegex.exec(content)) !== null) {
            const colName = colMatch[1].toLowerCase();
            if (colName === 'type' || colName === 'sequelize')
                continue;
            if (!migCols.has(colName)) {
                missingCols.push(colName);
            }
        }
        if (missingCols.length > 0) {
            results.push({ type: 'MISSING_COLUMNS', table: tableName, columns: missingCols, file: path.basename(fileToRead) });
        }
    }
}
console.log(JSON.stringify(results, null, 2));
