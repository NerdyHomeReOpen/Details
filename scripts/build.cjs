const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { execSync } = require("child_process");

const ROOT = path.resolve(__dirname, "..");
const DIST = path.join(ROOT, "dist");
const TMP = path.join(ROOT, "dist.tmp");
const OLD = path.join(ROOT, "dist.old");

const SOURCES = [
  { absDir: path.join(ROOT, "locales"), prefix: "locales" },
  { absDir: path.join(ROOT, "docs"), prefix: "docs" },
];

function sha256(buf) {
  return crypto.createHash("sha256").update(buf).digest("hex");
}

function gitVersion() {
  if (process.env.GITHUB_SHA) return process.env.GITHUB_SHA.slice(0, 12);
  try {
    return execSync("git rev-parse --short=12 HEAD", { cwd: ROOT })
      .toString()
      .trim();
  } catch {
    return "unknown";
  }
}

function walkRel(dir) {
  const out = [];
  (function recur(current) {
    for (const e of fs.readdirSync(current, { withFileTypes: true })) {
      const full = path.join(current, e.name);
      if (e.isDirectory()) recur(full);
      else if (e.isFile()) out.push(path.relative(dir, full));
    }
  })(dir);
  return out;
}

function copyTree(srcDir, destDir, prefix) {
  const records = [];
  for (const rel of walkRel(srcDir)) {
    const srcPath = path.join(srcDir, rel);
    const destPath = path.join(destDir, rel);
    fs.mkdirSync(path.dirname(destPath), { recursive: true });
    const data = fs.readFileSync(srcPath);
    fs.writeFileSync(destPath, data);
    records.push({
      path: path.posix.join(prefix, rel.split(path.sep).join("/")),
      size: data.length,
      sha256: sha256(data),
    });
  }
  return records;
}

function rmrf(p) {
  if (fs.existsSync(p)) fs.rmSync(p, { recursive: true, force: true });
}

function main() {
  rmrf(TMP);
  fs.mkdirSync(TMP, { recursive: true });

  const localesDir = path.join(ROOT, "locales");
  const docsDir = path.join(ROOT, "docs");

  const files = [];
  for (const { absDir, prefix } of SOURCES) {
    files.push(...copyTree(absDir, path.join(TMP, prefix), prefix));
  }
  files.sort((a, b) => a.path.localeCompare(b.path));

  const locales = fs
    .readdirSync(localesDir, { withFileTypes: true })
    .filter((e) => e.isDirectory())
    .map((e) => e.name)
    .sort();

  const namespaceSet = new Set();
  for (const loc of locales) {
    for (const f of fs.readdirSync(path.join(localesDir, loc))) {
      if (f.endsWith(".json")) namespaceSet.add(f.replace(/\.json$/, ""));
    }
  }
  const namespaces = [...namespaceSet].sort();

  const docs = fs
    .readdirSync(docsDir)
    .filter((f) => f.endsWith(".json"))
    .sort();

  const manifest = {
    version: gitVersion(),
    updatedAt: new Date().toISOString(),
    locales,
    namespaces,
    docs,
    files,
  };

  fs.writeFileSync(
    path.join(TMP, "manifest.json"),
    JSON.stringify(manifest, null, 2),
    "utf8"
  );

  rmrf(OLD);
  if (fs.existsSync(DIST)) fs.renameSync(DIST, OLD);
  fs.renameSync(TMP, DIST);
  rmrf(OLD);

  console.log(
    `built dist/ — ${files.length} files, ${locales.length} locales, version ${manifest.version}`
  );
}

main();
