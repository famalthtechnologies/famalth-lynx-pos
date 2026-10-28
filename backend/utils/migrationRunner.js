var __create = Object.create;
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __getProtoOf = Object.getPrototypeOf;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
  // If the importer is in node compatibility mode or this is not an ESM
  // file that has been converted to a CommonJS file using a Babel-
  // compatible transform (i.e. "__esModule" has not been set), then set
  // "default" to the CommonJS "module.exports" for node compatibility.
  isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
  mod
));
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);
var migrationRunner_exports = {};
__export(migrationRunner_exports, {
  default: () => migrationRunner_default,
  runMigrations: () => runMigrations
});
module.exports = __toCommonJS(migrationRunner_exports);
var import_migrations = __toESM(require("./migrations"));
async function runMigrations(db) {
  await db.query(`
    CREATE TABLE IF NOT EXISTS schema_version (
      version INT PRIMARY KEY,
      applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);
  const [rows] = await db.query(
    "SELECT MAX(version) as version FROM schema_version"
  );
  let currentVersion = rows[0]?.version || 0;
  for (const migration of import_migrations.default) {
    if (migration.version > currentVersion) {
      console.log("Running migration:", migration.version);
      try {
        await migration.up(db);
      } catch (migErr) {
        console.warn(`\u26A0\uFE0F Migration ${migration.version} notice:`, migErr.message);
        await db.query("ROLLBACK;").catch(() => {
        });
      }
      try {
        await db.query(
          "INSERT INTO schema_version(version) VALUES ($1) ON CONFLICT (version) DO NOTHING",
          { bind: [migration.version] }
        );
      } catch (_) {
      }
      currentVersion = migration.version;
    }
  }
}
runMigrations.default = runMigrations;
runMigrations.runMigrations = runMigrations;
module.exports = runMigrations;
var migrationRunner_default = runMigrations;
// Annotate the CommonJS export names for ESM import in node:
0 && (module.exports = {
  runMigrations
});
