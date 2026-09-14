import { createRequire } from 'node:module';
import { createServer } from 'node:http';
import { createHash } from 'node:crypto';
import { existsSync, readFileSync, statSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import os from 'node:os';

const root = fileURLToPath(new URL('.', import.meta.url));
const qa = path.join(root, 'generated', 'qa');
const temporary = path.join(root, 'generated', 'tmp');
const output = path.join(root, 'out');
mkdirSync(qa, { recursive: true });
mkdirSync(temporary, { recursive: true });
process.env.TEMP = temporary;
process.env.TMP = temporary;

const mp4Path = path.join(output, 'codex-resource-audit-v0.1.1-demo.mp4');
const webmPath = path.join(output, 'codex-resource-audit-v0.1.1-demo.webm');
const videoPath = existsSync(mp4Path) ? mp4Path : webmPath;
if (!existsSync(videoPath)) {
  throw new Error('No demo video found. Record WebM first, then optionally create MP4.');
}

const extension = path.extname(videoPath).toLowerCase();
const contentType = extension === '.mp4' ? 'video/mp4' : 'video/webm';
const route = '/demo' + extension;
const video = readFileSync(videoPath);
const hardFailures = [];

function validateQaEvidence() {
  const reportPath = path.join(qa, 'browser-checks.json');
  if (!existsSync(reportPath)) {
    hardFailures.push('Current browser QA evidence is missing. Run record-demo.mjs --qa-only.');
    return { status: 'FAIL', reason: 'missing browser-checks.json' };
  }

  let report;
  try {
    report = JSON.parse(readFileSync(reportPath, 'utf8'));
  } catch (error) {
    hardFailures.push('Browser QA evidence is unreadable: ' + error.message);
    return { status: 'FAIL', reason: 'invalid browser-checks.json' };
  }

  const expectedScenes = ['intro', 'start', 'workflow', 'observe', 'delta', 'branch', 'next', 'controls', 'final'];
  const actualScenes = report.checks?.map(check => check.scene) ?? [];
  const sourceFiles = ['demo.html', 'demo.css', 'demo.js', 'replay-data.json'];
  const currentHashes = Object.fromEntries(sourceFiles.map(file => [
    file,
    createHash('sha256').update(readFileSync(path.join(root, file))).digest('hex')
  ]));
  const hashesMatch = sourceFiles.every(file => report.sourceSha256?.[file] === currentHashes[file]);
  const scenesMatch = JSON.stringify(actualScenes) === JSON.stringify(expectedScenes);
  const checksPass =
    report.kind === 'SANITIZED_REPLAY' &&
    report.liveCapture === false &&
    report.pageIdentity === 'PASS' &&
    report.privacyAndClaimReview === 'PASS' &&
    Array.isArray(report.consoleErrors) &&
    report.consoleErrors.length === 0 &&
    scenesMatch &&
    hashesMatch;

  if (!checksPass) {
    hardFailures.push('Browser QA evidence is missing, stale, or incomplete for the current nine-scene source.');
  }
  return {
    status: checksPass ? 'PASS' : 'FAIL',
    scenes: actualScenes,
    expectedScenes,
    scenesMatch,
    sourceHashesMatch: hashesMatch
  };
}

function validateRecordingEvidence() {
  const reportPath = path.join(qa, 'recording.json');
  if (!existsSync(reportPath) || !existsSync(webmPath)) {
    hardFailures.push('Current recording evidence is missing. Run record-demo.mjs.');
    return { status: 'FAIL', reason: 'missing recording.json or WebM' };
  }

  let report;
  try {
    report = JSON.parse(readFileSync(reportPath, 'utf8'));
  } catch (error) {
    hardFailures.push('Recording evidence is unreadable: ' + error.message);
    return { status: 'FAIL', reason: 'invalid recording.json' };
  }

  const sourceFiles = ['demo.html', 'demo.css', 'demo.js', 'replay-data.json'];
  const sourceHashesMatch = sourceFiles.every(file =>
    report.sourceSha256?.[file] === createHash('sha256').update(readFileSync(path.join(root, file))).digest('hex')
  );
  const webmHash = createHash('sha256').update(readFileSync(webmPath)).digest('hex');
  const webmHashMatches = report.webm?.sha256 === webmHash;
  const mp4IsCurrent = extension !== '.mp4' || statSync(mp4Path).mtimeMs >= statSync(webmPath).mtimeMs;
  const checksPass =
    report.kind === 'SANITIZED_REPLAY' &&
    report.liveCapture === false &&
    sourceHashesMatch &&
    webmHashMatches &&
    mp4IsCurrent;

  if (!checksPass) {
    hardFailures.push('The video is stale for the current source, or MP4 predates its recorder-native WebM.');
  }
  return {
    status: checksPass ? 'PASS' : 'FAIL',
    sourceHashesMatch,
    webmHashMatches,
    mp4IsCurrent
  };
}

function rational(value) {
  if (!value || value === '0/0') return null;
  const [numerator, denominator = '1'] = String(value).split('/').map(Number);
  if (!Number.isFinite(numerator) || !Number.isFinite(denominator) || denominator === 0) return null;
  return numerator / denominator;
}

function finiteNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function resolveFromPath(name) {
  const locator = process.platform === 'win32' ? 'where.exe' : 'which';
  const located = spawnSync(locator, [name], { encoding: 'utf8', windowsHide: true, shell: false });
  if (located.error || located.status !== 0) return null;
  return located.stdout.split(/\r?\n/).map(value => value.trim()).find(Boolean) ?? null;
}

function inspectWithFfprobe() {
  const failuresBefore = hardFailures.length;
  const ffprobeExecutable = resolveFromPath('ffprobe') ?? 'ffprobe';
  const probe = spawnSync(ffprobeExecutable, [
    '-v', 'error',
    '-select_streams', 'v:0',
    '-count_frames',
    '-show_entries',
    'stream=codec_name,pix_fmt,width,height,r_frame_rate,avg_frame_rate,nb_read_frames,nb_frames:format=duration',
    '-of', 'json',
    videoPath
  ], { encoding: 'utf8', windowsHide: true, shell: false });

  if (probe.error?.code === 'ENOENT') {
    return { status: 'UNAVAILABLE', reason: 'ffprobe was not found on PATH' };
  }
  if (probe.error || probe.status !== 0) {
    hardFailures.push('FFprobe could not read the complete video: ' + (probe.error?.message || probe.stderr.trim()));
    return { status: 'FAIL' };
  }

  let result;
  try {
    result = JSON.parse(probe.stdout);
  } catch (error) {
    hardFailures.push('FFprobe returned invalid JSON: ' + error.message);
    return { status: 'FAIL' };
  }

  const stream = result.streams?.[0];
  if (!stream) {
    hardFailures.push('FFprobe found no video stream.');
    return { status: 'FAIL' };
  }

  const duration = finiteNumber(result.format?.duration);
  const fps = rational(stream.avg_frame_rate) ?? rational(stream.r_frame_rate);
  const readableFrames = finiteNumber(stream.nb_read_frames) ?? finiteNumber(stream.nb_frames);
  const expectedFrames = duration !== null && fps !== null ? Math.round(duration * fps) : null;
  const frameCountMatches = readableFrames === null || expectedFrames === null
    ? null
    : Math.abs(readableFrames - expectedFrames) <= 1;

  if (stream.width !== 1280 || stream.height !== 720) {
    hardFailures.push(`FFprobe resolution is ${stream.width}x${stream.height}; expected 1280x720.`);
  }
  if (duration === null || duration < 40 || duration > 45) {
    hardFailures.push(`FFprobe duration is ${duration}; expected 40-45 seconds.`);
  }
  if (fps === null || Math.abs(fps - 25) > 0.01) {
    hardFailures.push(`FFprobe frame rate is ${fps}; expected 25 fps.`);
  }
  if (frameCountMatches === false) {
    hardFailures.push(`FFprobe read ${readableFrames} frames; duration and rate imply ${expectedFrames}.`);
  }
  if (extension === '.mp4' && (stream.codec_name !== 'h264' || stream.pix_fmt !== 'yuv420p')) {
    hardFailures.push(`MP4 encoding is ${stream.codec_name}/${stream.pix_fmt}; expected h264/yuv420p.`);
  }
  if (extension === '.webm' && stream.codec_name !== 'vp8') {
    hardFailures.push(`WebM codec is ${stream.codec_name}; expected vp8.`);
  }

  return {
    status: hardFailures.length === failuresBefore ? 'PASS' : 'FAIL',
    executable: ffprobeExecutable,
    codec: stream.codec_name,
    pixelFormat: stream.pix_fmt,
    width: stream.width,
    height: stream.height,
    duration,
    fps,
    readableFrames,
    expectedFrames,
    frameCount: frameCountMatches === null ? 'UNAVAILABLE' : frameCountMatches ? 'PASS' : 'FAIL'
  };
}

const qaEvidence = validateQaEvidence();
const recordingEvidence = validateRecordingEvidence();
const ffprobe = inspectWithFfprobe();
const require = createRequire(import.meta.url);
const { chromium } = require(path.join(
  os.homedir(),
  '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright'
));

const server = createServer((request, response) => {
  if (request.url !== route) {
    response.writeHead(404);
    response.end();
    return;
  }
  response.writeHead(200, {
    'Content-Type': contentType,
    'Content-Length': video.length,
    'Access-Control-Allow-Origin': '*'
  });
  response.end(video);
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));

let browser;
try {
  browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await context.newPage();
  await page.setContent(
    `<body style="margin:0;background:#0d1417"><video id="video" muted style="width:1280px;height:720px" src="http://127.0.0.1:${server.address().port}${route}"></video></body>`
  );
  const playback = await page.evaluate(async () => {
    const player = document.getElementById('video');
    if (player.readyState < 1) {
      await new Promise((resolve, reject) => {
        player.onloadedmetadata = resolve;
        player.onerror = () => reject(new Error('Video metadata failed'));
      });
    }
    let callbacks = 0;
    player.requestVideoFrameCallback(function count() {
      callbacks += 1;
      if (!player.ended) player.requestVideoFrameCallback(count);
    });
    const ended = new Promise((resolve, reject) => {
      player.onended = resolve;
      player.onerror = () => reject(new Error('Video playback failed'));
      setTimeout(() => reject(new Error('Video playback timed out')), 60000);
    });
    await player.play();
    await ended;
    const quality = player.getVideoPlaybackQuality();
    return {
      duration: player.duration,
      width: player.videoWidth,
      height: player.videoHeight,
      ended: player.ended,
      decodedCallbacks: callbacks,
      totalVideoFrames: quality.totalVideoFrames,
      droppedVideoFrames: quality.droppedVideoFrames,
      corruptedVideoFrames: quality.corruptedVideoFrames
    };
  });

  if (playback.duration < 40 || playback.duration > 45) {
    hardFailures.push(`Browser duration is ${playback.duration}; expected 40-45 seconds.`);
  }
  if (playback.width !== 1280 || playback.height !== 720) {
    hardFailures.push(`Browser resolution is ${playback.width}x${playback.height}; expected 1280x720.`);
  }
  if (!playback.ended) hardFailures.push('Browser playback did not reach the end.');
  if (playback.corruptedVideoFrames !== 0) {
    hardFailures.push(`Browser reported ${playback.corruptedVideoFrames} corrupted frames.`);
  }

  const bundledFfmpeg = path.join(
    os.homedir(),
    'AppData/Local/ms-playwright/ffmpeg-1011/ffmpeg-win64.exe'
  );
  const pathFfmpeg = resolveFromPath('ffmpeg');
  const ffmpeg = pathFfmpeg ?? (existsSync(bundledFfmpeg) ? bundledFfmpeg : 'ffmpeg');
  const ffmpegSource = pathFfmpeg ? 'PATH' : existsSync(bundledFfmpeg) ? 'PLAYWRIGHT_BUNDLED_FALLBACK' : 'UNRESOLVED';
  const demoSource = readFileSync(path.join(root, 'demo.js'), 'utf8');
  const sceneTimeline = [...demoSource.matchAll(/\{\s*at:\s*([0-9.]+),\s*id:\s*'([^']+)'/g)]
    .map(match => ({ time: Number(match[1]) + 0.2, scene: match[2] }));
  const frameSamples = [
    ...sceneTimeline,
    { time: playback.duration - 0.15, scene: 'final-end' }
  ];
  const frames = [];
  for (const [index, sample] of frameSamples.entries()) {
    const { time, scene } = sample;
    const destination = path.join(qa, 'review-frame-' + String(index).padStart(2, '0') + '.png');
    const argv = [
      '-v', 'error', '-y',
      '-ss', String(time),
      '-i', videoPath,
      '-frames:v', '1',
      destination
    ];
    const decoded = spawnSync(ffmpeg, argv, {
      encoding: 'utf8',
      windowsHide: true,
      shell: false
    });
    if (decoded.error || decoded.status !== 0) {
      hardFailures.push('Frame decode failed at ' + time + ' seconds: ' + (decoded.error?.message || decoded.stderr.trim()));
      break;
    }
    frames.push({ scene, time, file: path.basename(destination) });
  }
  const extractedScenes = frames.filter(frame => frame.scene !== 'final-end').map(frame => frame.scene);
  const sceneCoverage = JSON.stringify(extractedScenes) === JSON.stringify(qaEvidence.expectedScenes);
  const finalFrameCovered = frames.some(frame => frame.scene === 'final-end');
  if (!sceneCoverage) hardFailures.push('Representative frames do not cover all nine expected scenes.');
  if (!finalFrameCovered) hardFailures.push('Final-frame extraction did not complete.');

  const report = {
    kind: 'SANITIZED_REPLAY',
    liveCapture: false,
    file: path.basename(videoPath),
    preferredReviewFormat: 'MP4 when present; WebM fallback',
    fileIntegrity: ffprobe.status === 'UNAVAILABLE' ? 'FALLBACK_BROWSER_METADATA' : ffprobe.status,
    qaEvidence,
    recordingEvidence,
    ffprobe,
    ffmpeg: {
      executable: ffmpeg,
      source: ffmpegSource,
      processApi: 'spawnSync',
      shell: false,
      argumentHandling: 'raw argv values with no embedded shell quotes',
      seekOrder: '-ss before -i',
      inputPath: videoPath,
      outputDirectory: qa,
      samples: frameSamples
    },
    playback,
    gates: {
      playbackCompletion: playback.ended ? 'PASS' : 'FAIL',
      resolution: playback.width === 1280 && playback.height === 720 ? 'PASS' : 'FAIL',
      duration: playback.duration >= 40 && playback.duration <= 45 ? 'PASS' : 'FAIL',
      frameCount: ffprobe.frameCount ?? 'UNAVAILABLE',
      corruptedFrames: playback.corruptedVideoFrames === 0 ? 'PASS' : 'FAIL',
      playbackDroppedFrames: playback.droppedVideoFrames,
      playbackDropStatus: playback.droppedVideoFrames > 0 ? 'WARNING' : 'PASS',
      sceneCoverage: sceneCoverage ? 'PASS' : 'FAIL',
      finalFrame: finalFrameCovered ? 'PASS' : 'FAIL'
    },
    playbackDiagnostics: {
      decodedCallbacks: 'requestVideoFrameCallback callbacks delivered during real-time playback; not an encoded-file frame count',
      totalVideoFrames: 'browser playback-quality count of presented and dropped frames; not an independent file-integrity count',
      droppedVideoFrames: 'playback/display diagnostic; nonzero is a warning, not proof of encoded-frame loss'
    },
    frames,
    visualReview: frames.length === frameSamples.length ? 'FRAMES_EXTRACTED_REQUIRES_HUMAN_REVIEW' : 'FRAME_EXTRACTION_FAILED',
    hardFailures,
    result: hardFailures.length ? 'FAIL' : 'PASS'
  };
  writeFileSync(path.join(qa, 'video-review.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report));
  await context.close();

  if (hardFailures.length) {
    throw new Error('Video acceptance gate failed: ' + hardFailures.join(' '));
  }
} finally {
  await browser?.close();
  await new Promise(resolve => server.close(resolve));
}
