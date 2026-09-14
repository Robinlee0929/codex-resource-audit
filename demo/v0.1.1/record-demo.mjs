import { createRequire } from 'node:module';
import { createServer } from 'node:http';
import { createHash } from 'node:crypto';
import { copyFileSync, readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import os from 'node:os';

const root = fileURLToPath(new URL('.', import.meta.url));
const require = createRequire(import.meta.url);
const playwrightPath = path.join(
  os.homedir(),
  '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright'
);
const { chromium } = require(playwrightPath);
const output = path.join(root, 'out');
const qa = path.join(root, 'generated', 'qa');
const temporary = path.join(root, 'generated', 'tmp');
mkdirSync(output, { recursive: true });
mkdirSync(qa, { recursive: true });
mkdirSync(temporary, { recursive: true });
process.env.TEMP = temporary;
process.env.TMP = temporary;

const allowed = new Map([
  ['/', 'demo.html'],
  ['/demo.html', 'demo.html'],
  ['/demo.css', 'demo.css'],
  ['/demo.js', 'demo.js'],
  ['/replay-data.json', 'replay-data.json']
]);
const contentTypes = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.json': 'application/json'
};
const server = createServer((request, response) => {
  const file = allowed.get(request.url);
  if (!file) {
    response.writeHead(404);
    response.end();
    return;
  }
  response.writeHead(200, { 'Content-Type': contentTypes[path.extname(file)] + '; charset=utf-8' });
  response.end(readFileSync(path.join(root, file)));
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const baseUrl = `http://127.0.0.1:${server.address().port}`;
const sourceFiles = ['demo.html', 'demo.css', 'demo.js', 'replay-data.json'];
const sourceSha256 = Object.fromEntries(sourceFiles.map(file => [
  file,
  createHash('sha256').update(readFileSync(path.join(root, file))).digest('hex')
]));

let browser;
const consoleErrors = [];
const checks = [];
try {
  browser = await chromium.launch({ headless: true });
  const qaContext = await browser.newContext({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
  const page = await qaContext.newPage();
  page.on('pageerror', error => consoleErrors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error') consoleErrors.push(message.text());
  });
  await page.route('**/*', route =>
    route.request().url().startsWith(baseUrl) ? route.continue() : route.abort()
  );
  await page.goto(baseUrl + '/demo.html');
  await page.waitForFunction(() => window.demoReady === true);

  const timeline = await page.evaluate(() => window.demo.timeline);
  for (const item of timeline) {
    await page.evaluate(time => window.demo.seek(time), item.at + 0.15);
    const check = await page.evaluate(() => {
      const stage = document.getElementById('stage');
      const scene = document.querySelector('.scene.active');
      const replayLabel = document.querySelector('.replay-label');
      const replayLabelStyle = getComputedStyle(replayLabel);
      const replayLabelBounds = replayLabel.getBoundingClientRect();
      const elements = [
        ...scene.querySelectorAll('h1,h2,h3,p,pre,div,span'),
        ...document.querySelectorAll('header,header span')
      ];
      const overflow = elements
        .filter(element => element.scrollWidth > element.clientWidth + 1 || element.getBoundingClientRect().bottom > 652)
        .map(element => element.tagName + ': ' + element.textContent.trim().slice(0, 90));
      return {
        scene: document.body.dataset.scene,
        text: scene.innerText,
        frameText: stage.innerText,
        replayLabel: {
          text: replayLabel.innerText,
          visible:
            replayLabelStyle.display !== 'none' &&
            replayLabelStyle.visibility !== 'hidden' &&
            Number(replayLabelStyle.opacity) > 0 &&
            replayLabelBounds.width > 0 &&
            replayLabelBounds.height > 0 &&
            replayLabelBounds.left >= 0 &&
            replayLabelBounds.top >= 0 &&
            replayLabelBounds.right <= innerWidth &&
            replayLabelBounds.bottom <= innerHeight,
          fontSize: Number.parseFloat(replayLabelStyle.fontSize)
        },
        overflow
      };
    });
    if (check.overflow.length) throw new Error('Layout overflow: ' + JSON.stringify(check));
    if (
      !check.replayLabel.visible ||
      check.replayLabel.fontSize < 15 ||
      check.replayLabel.text !== 'SANITIZED REPLAY · NOT A LIVE CAPTURE'
    ) {
      throw new Error('Sanitized replay disclaimer is not visibly rendered with canonical wording.');
    }
    checks.push(check);
    await page.screenshot({ path: path.join(qa, check.scene + '.png') });
  }

  // Browser innerText may insert harmless line breaks around flex children.
  // Normalize whitespace only; every required word and punctuation mark remains exact.
  const normalizeVisibleText = value => value.replace(/\s+/g, ' ').trim();
  const allText = normalizeVisibleText(checks.map(check => check.frameText).join('\n'));
  const required = [
    '.\\codex-resource-audit.ps1 -Mode Guided',
    'SANITIZED REPLAY · NOT A LIVE CAPTURE',
    'Guided is the recommended normal-user workflow.',
    'Select the Codex instance you intend to observe.',
    'VERIFY records your operator assertion.',
    'Exact Session identity is revalidated separately.',
    'BASELINE BEFORE ACTIVITY',
    'PERFORM THE CODEX ACTIVITY',
    'CAPTURE TASK ACTIVE',
    'TASK FINISHES',
    'OPERATOR DECLARES TASK_END',
    'Observation continues after TASK_END to see which process identities remain observed.',
    'TASK_END != PROCESS_EXIT',
    'OBSERVATION_INTERVAL != LIFECYCLE_GRACE',
    '4\nconfirmed Codex-owned',
    'Four processes do not mean four sessions.',
    'PROCESS_BRANCH != LOGICAL_SESSION',
    'PROCESS_PARENTAGE != TOOL_CAUSATION',
    'NO_LONGER_OBSERVED != EXIT_CONFIRMED',
    'AVAILABLE · 0',
    'UNKNOWN != CODEX',
    'STILL_OBSERVED != RESIDUE'
  ];
  for (const claim of required) {
    if (!allText.includes(normalizeVisibleText(claim))) {
      throw new Error('Missing required demo claim: ' + claim);
    }
  }
  const prohibited = [
    /[A-Z]:\\/i,
    /\\Users\\/i,
    /\bPID\s*[:=]\s*\d+/i,
    /token\s*[:=]/i,
    /account[_ -]?id/i,
    /cleanup succeeded/i,
    /exited normally/i,
    /Browser creates no processes/i,
    /leak detected/i
  ];
  for (const pattern of prohibited) {
    if (pattern.test(allText)) throw new Error('Privacy or claim review failed: ' + pattern);
  }
  if (consoleErrors.length) throw new Error(consoleErrors.join('\n'));

  // The poster is the exact Branch frame that passed the same visible-claim,
  // privacy, and layout checks above, including the persistent replay label.
  copyFileSync(
    path.join(qa, 'branch.png'),
    path.join(output, 'codex-resource-audit-v0.1.1-demo.png')
  );
  writeFileSync(
    path.join(qa, 'browser-checks.json'),
    JSON.stringify({
      kind: 'SANITIZED_REPLAY',
      liveCapture: false,
      viewport: '1280x720',
      pageIdentity: 'PASS',
      consoleErrors,
      privacyAndClaimReview: 'PASS',
      sourceSha256,
      checks
    }, null, 2)
  );
  await qaContext.close();

  if (!process.argv.includes('--qa-only')) {
    const context = await browser.newContext({
      viewport: { width: 1280, height: 720 },
      deviceScaleFactor: 1,
      recordVideo: { dir: output, size: { width: 1280, height: 720 } }
    });
    const recording = await context.newPage();
    recording.on('pageerror', error => consoleErrors.push(error.message));
    await recording.route('**/*', route =>
      route.request().url().startsWith(baseUrl) ? route.continue() : route.abort()
    );
    await recording.goto(baseUrl + '/demo.html');
    await recording.waitForFunction(() => window.demoReady === true);
    const video = recording.video();
    await recording.evaluate(() => window.demo.start());
    await context.close();
    const webmPath = path.join(output, 'codex-resource-audit-v0.1.1-demo.webm');
    await video.saveAs(webmPath);
    await video.delete();
    if (consoleErrors.length) throw new Error(consoleErrors.join('\n'));
    writeFileSync(
      path.join(qa, 'recording.json'),
      JSON.stringify({
        kind: 'SANITIZED_REPLAY',
        liveCapture: false,
        sourceSha256,
        webm: {
          file: path.basename(webmPath),
          sha256: createHash('sha256').update(readFileSync(webmPath)).digest('hex')
        }
      }, null, 2)
    );
    console.log('DEMO_RECORDING: PASS');
  } else {
    console.log('DEMO_QA: PASS');
  }
} finally {
  await browser?.close();
  await new Promise(resolve => server.close(resolve));
}
