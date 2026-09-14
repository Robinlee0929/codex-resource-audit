const data = await fetch('./replay-data.json').then(response => {
  if (!response.ok) throw new Error('Sanitized replay data is unavailable.');
  return response.json();
});

if (data.kind !== 'SANITIZED_REPLAY' || data.liveCapture !== false) {
  throw new Error('Demo source must remain an explicitly sanitized replay.');
}

document.getElementById('created-count').textContent = data.taskDelta.confirmedCreated;
document.getElementById('still-count').textContent = data.taskDelta.stillObservedAtS4;
document.getElementById('gone-count').textContent = data.taskDelta.noLongerObservedByS4;
document.getElementById('first-stage').textContent = data.taskDelta.firstSeen;
document.getElementById('last-stage').textContent = data.taskDelta.lastSeen;
document.getElementById('current-state').textContent = data.taskDelta.currentResult;
document.getElementById('ancestor').textContent = data.branch.preExistingAncestor;

const branchLines = [
  data.branch.root,
  ...data.branch.children.map((name, index) =>
    (index === data.branch.children.length - 1 ? '  `-- ' : '  |-- ') + name
  )
];
document.getElementById('branch-tree').textContent = branchLines.join('\n');

const chapters = ['QUESTION', 'START', 'SELECT + VERIFY', 'OBSERVE', 'TASK DELTA', 'BRANCH', 'NEXT STEP', 'CONTROLS', 'BOUNDARIES'];
const timeline = [
  { at: 0, id: 'intro', chapter: 1 },
  { at: 3.8, id: 'start', chapter: 2 },
  { at: 8, id: 'workflow', chapter: 3 },
  { at: 13, id: 'observe', chapter: 4 },
  { at: 19.5, id: 'delta', chapter: 5 },
  { at: 25, id: 'branch', chapter: 6 },
  { at: 30.5, id: 'next', chapter: 7 },
  { at: 35, id: 'controls', chapter: 8 },
  { at: 39, id: 'final', chapter: 9 }
];
const duration = 43;
let animationFrame = 0;

function render(seconds) {
  const time = Math.max(0, Math.min(seconds, duration));
  const state = timeline.findLast(item => time >= item.at);
  for (const scene of document.querySelectorAll('.scene')) {
    scene.classList.toggle('active', scene.id === state.id);
  }
  document.getElementById('chapter').textContent =
    String(state.chapter).padStart(2, '0') + ' / 09 · ' + chapters[state.chapter - 1];
  document.getElementById('progress').style.width = (time / duration * 100) + '%';
  document.body.dataset.scene = state.id;
  return state.id;
}

function resize() {
  const scale = Math.min(innerWidth / 1280, innerHeight / 720);
  document.getElementById('stage').style.transform = 'translate(-50%,-50%) scale(' + scale + ')';
}

addEventListener('resize', resize);
resize();
render(0);

window.demo = {
  duration,
  timeline,
  seek(seconds) {
    cancelAnimationFrame(animationFrame);
    return render(seconds);
  },
  start() {
    cancelAnimationFrame(animationFrame);
    const started = performance.now();
    return new Promise(resolve => {
      function tick(now) {
        const elapsed = (now - started) / 1000;
        render(elapsed);
        if (elapsed < duration) animationFrame = requestAnimationFrame(tick);
        else resolve();
      }
      animationFrame = requestAnimationFrame(tick);
    });
  }
};
window.demoReady = true;
