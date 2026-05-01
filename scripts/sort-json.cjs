const fs = require('fs');
const path = require('path');

function sortJsonFile(filePath) {
  try {
    if (!fs.existsSync(filePath)) {
      console.error(`Error: File ${filePath} does not exist`);
      return false;
    }

    if (!filePath.endsWith('.json')) {
      console.error(`Error: ${filePath} is not a JSON file`);
      return false;
    }

    const originalContent = fs.readFileSync(filePath, 'utf8');
    const jsonData = JSON.parse(originalContent);

    if (Array.isArray(jsonData)) {
      console.log(`Skip ${filePath} (array root)`);
      return true;
    }

    if (jsonData === null || typeof jsonData !== 'object') {
      console.log(`Skip ${filePath} (not an object)`);
      return true;
    }

    console.log(`Sorting ${filePath} (${Object.keys(jsonData).length} keys)`);

    const sortedKeys = Object.keys(jsonData).sort();
    const sortedData = {};

    sortedKeys.forEach((key) => {
      sortedData[key] = jsonData[key];
    });

    const sortedContent = JSON.stringify(sortedData, null, 2);

    fs.writeFileSync(filePath, sortedContent, 'utf8');

    console.log(`${filePath} sorted`);

    return true;
  } catch (error) {
    console.error(`Error processing ${filePath}: ${error.message}`);
    return false;
  }
}

function findJsonFiles(dir) {
  const results = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === 'node_modules' || entry.name.startsWith('.')) {
        continue;
      }
      results.push(...findJsonFiles(fullPath));
    } else if (entry.isFile() && entry.name.endsWith('.json')) {
      results.push(fullPath);
    }
  }

  return results;
}

function main() {
  const args = process.argv.slice(2);

  if (args.length > 0 && (args[0] === '-h' || args[0] === '--help')) {
    console.log('JSON file sorting tool');
    console.log('\nUsage:');
    console.log('  node sort-json.cjs [directory]');
    console.log('\nExample:');
    console.log('  node sort-json.cjs');
    console.log('  node sort-json.cjs ./src/locales');
    console.log('\nFeatures:');
    console.log('  - Recursively find and sort all JSON files under the given directory');
    console.log('  - Default to current working directory when none provided');
    console.log('  - Skip files whose root is a JSON array');
    console.log('  - Sort object keys alphabetically');
    return;
  }

  const targetDir = args[0] ? (path.isAbsolute(args[0]) ? args[0] : path.resolve(args[0])) : process.cwd();

  if (!fs.existsSync(targetDir)) {
    console.error(`Error: Directory ${targetDir} does not exist`);
    process.exit(1);
  }

  const stat = fs.statSync(targetDir);
  if (!stat.isDirectory()) {
    console.error(`Error: ${targetDir} is not a directory`);
    process.exit(1);
  }

  console.log(`Target directory: ${targetDir}`);

  const jsonFiles = findJsonFiles(targetDir);

  if (jsonFiles.length === 0) {
    console.log('No JSON files found.');
    return;
  }

  console.log(`Found ${jsonFiles.length} JSON file(s)\n`);

  let successCount = 0;
  let failCount = 0;

  for (const file of jsonFiles) {
    const ok = sortJsonFile(file);
    if (ok) {
      successCount++;
    } else {
      failCount++;
    }
  }

  console.log(`\nDone! Success: ${successCount}, Failed: ${failCount}`);

  if (failCount > 0) {
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = { sortJsonFile, findJsonFiles };
