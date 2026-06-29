#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const HOME = process.env.HOME;
const COLORS_FILE = path.join(HOME, '.cache/hyde/wallbash/darkreader.json');
const EXT_ID = 'eimadpbcbfnmbkopoojfekhnkhdbieeh';
const BRAVE_CONFIG = path.join(HOME, '.config/BraveSoftware/Brave-Browser/Default');
const LIBS_DIR = path.join(HOME, '.local/share/kitty-wallbash');

function findLeveldown() {
  const dirs = [
    path.join(LIBS_DIR, 'node_modules'),
    path.join(__dirname, '..', 'node_modules'),
    path.join(__dirname, 'node_modules'),
  ];
  for (const dir of dirs) {
    const p = path.join(dir, 'leveldown');
    try { if (fs.statSync(p).isDirectory()) return p; } catch {}
  }
  return null;
}

function main() {
  if (!fs.existsSync(COLORS_FILE)) {
    console.error('No colors file at', COLORS_FILE);
    console.error('Change your wallpaper first.');
    process.exit(1);
  }

  const wallColors = JSON.parse(fs.readFileSync(COLORS_FILE, 'utf-8'));
  const c = wallColors.darkreader.colors;

  const ldPath = findLeveldown();
  if (!ldPath) {
    console.error('leveldown not found. Run: npm install leveldown --prefix', LIBS_DIR);
    process.exit(2);
  }

  const leveldown = require(ldPath);

  const dbPaths = [
    path.join(BRAVE_CONFIG, 'Sync Extension Settings', EXT_ID),
    path.join(BRAVE_CONFIG, 'Local Extension Settings', EXT_ID),
  ];

  let tried = 0;

  function tryDb() {
    if (tried >= dbPaths.length) {
      console.error('Could not update Dark Reader settings. Is Brave running?');
      process.exit(3);
    }

    const dbPath = dbPaths[tried++];
    const db = leveldown(dbPath);
    const label = path.basename(path.dirname(dbPath));

    db.open({ createIfMissing: false }, (err) => {
      if (err) {
        console.error('Cannot open', label, err.message);
        return tryDb();
      }

      db.get('theme', (err, value) => {
        if (err || !value) {
          console.error('No theme key in', label);
          db.close(() => tryDb());
          return;
        }

        let theme;
        try {
          theme = JSON.parse(value.toString());
        } catch (e) {
          console.error('Invalid theme JSON in', label);
          db.close(() => process.exit(4));
          return;
        }

        const newTheme = Object.assign({}, theme, {
          darkSchemeBackgroundColor: c.darkSchemeBackgroundColor,
          darkSchemeTextColor: c.darkSchemeTextColor,
          lightSchemeBackgroundColor: c.lightSchemeBackgroundColor,
          lightSchemeTextColor: c.lightSchemeTextColor,
          scrollbarColor: c.scrollbarColor,
          selectionColor: c.selectionColor,
          selectionTextColor: c.selectionTextColor || c.selectionColor,
        });

        db.put('theme', JSON.stringify(newTheme), (err) => {
          if (err) {
            console.error('Write error:', err.message);
            db.close(() => process.exit(5));
            return;
          }
          db.close(() => {
            console.log('Dark Reader colors updated in', label);
            process.exit(0);
          });
        });
      });
    });
  }

  tryDb();
}

main();
