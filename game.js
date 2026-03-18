'use strict';

// ============================================================
// Constants
// ============================================================
const COLS = 10;
const ROWS = 20;
const BLOCK = 30; // px per cell

const COLORS = {
  I: '#00cfcf',
  O: '#f0c000',
  T: '#a000f0',
  S: '#00b000',
  Z: '#d00000',
  J: '#0050f0',
  L: '#f0a000',
};

// Tetromino shapes — each shape is an array of rotations.
// Each rotation is a 2-D array of rows.
const TETROMINOES = {
  I: [
    [[0,0,0,0],[1,1,1,1],[0,0,0,0],[0,0,0,0]],
    [[0,0,1,0],[0,0,1,0],[0,0,1,0],[0,0,1,0]],
    [[0,0,0,0],[0,0,0,0],[1,1,1,1],[0,0,0,0]],
    [[0,1,0,0],[0,1,0,0],[0,1,0,0],[0,1,0,0]],
  ],
  O: [
    [[1,1],[1,1]],
  ],
  T: [
    [[0,1,0],[1,1,1],[0,0,0]],
    [[0,1,0],[0,1,1],[0,1,0]],
    [[0,0,0],[1,1,1],[0,1,0]],
    [[0,1,0],[1,1,0],[0,1,0]],
  ],
  S: [
    [[0,1,1],[1,1,0],[0,0,0]],
    [[0,1,0],[0,1,1],[0,0,1]],
    [[0,0,0],[0,1,1],[1,1,0]],
    [[1,0,0],[1,1,0],[0,1,0]],
  ],
  Z: [
    [[1,1,0],[0,1,1],[0,0,0]],
    [[0,0,1],[0,1,1],[0,1,0]],
    [[0,0,0],[1,1,0],[0,1,1]],
    [[0,1,0],[1,1,0],[1,0,0]],
  ],
  J: [
    [[1,0,0],[1,1,1],[0,0,0]],
    [[0,1,1],[0,1,0],[0,1,0]],
    [[0,0,0],[1,1,1],[0,0,1]],
    [[0,1,0],[0,1,0],[1,1,0]],
  ],
  L: [
    [[0,0,1],[1,1,1],[0,0,0]],
    [[0,1,0],[0,1,0],[0,1,1]],
    [[0,0,0],[1,1,1],[1,0,0]],
    [[1,1,0],[0,1,0],[0,1,0]],
  ],
};

const SCORE_TABLE = [0, 100, 300, 500, 800];

// Drop interval in ms for each level (level 1..15+)
function dropInterval(level) {
  return Math.max(100, 1000 - (level - 1) * 75);
}

// ============================================================
// Canvas setup
// ============================================================
const boardCanvas = document.getElementById('board');
const ctx = boardCanvas.getContext('2d');

const nextCanvas = document.getElementById('next');
const nCtx = nextCanvas.getContext('2d');

// ============================================================
// Game state
// ============================================================
let board;
let boardColors;
let current;   // { type, rotation, x, y }
let next;      // { type, rotation }
let score;
let level;
let lines;
let gameOver;
let lastTime;
let dropCounter;
let animationId;

// ============================================================
// Initialise / reset
// ============================================================
function initGame() {
  board = Array.from({ length: ROWS }, () => Array(COLS).fill(0));
  boardColors = Array.from({ length: ROWS }, () => Array(COLS).fill(null));
  score = 0;
  level = 1;
  lines = 0;
  gameOver = false;
  dropCounter = 0;
  lastTime = 0;

  next = randomPiece();
  spawnPiece();
  updateUI();
  hideOverlay();

  if (animationId) cancelAnimationFrame(animationId);
  animationId = requestAnimationFrame(gameLoop);
}

function randomPiece() {
  const types = Object.keys(TETROMINOES);
  const type = types[Math.floor(Math.random() * types.length)];
  return { type, rotation: 0 };
}

function spawnPiece() {
  current = {
    type: next.type,
    rotation: next.rotation,
    x: Math.floor(COLS / 2) - Math.floor(TETROMINOES[next.type][0][0].length / 2),
    y: 0,
  };
  next = randomPiece();

  if (!isValid(current.x, current.y, currentShape())) {
    triggerGameOver();
  }
}

function currentShape() {
  return TETROMINOES[current.type][current.rotation];
}

// ============================================================
// Collision / validation
// ============================================================
function isValid(px, py, shape) {
  for (let r = 0; r < shape.length; r++) {
    for (let c = 0; c < shape[r].length; c++) {
      if (!shape[r][c]) continue;
      const nx = px + c;
      const ny = py + r;
      if (nx < 0 || nx >= COLS || ny >= ROWS) return false;
      if (ny >= 0 && board[ny][nx]) return false;
    }
  }
  return true;
}

// ============================================================
// Movement
// ============================================================
function moveLeft() {
  if (isValid(current.x - 1, current.y, currentShape())) {
    current.x--;
  }
}

function moveRight() {
  if (isValid(current.x + 1, current.y, currentShape())) {
    current.x++;
  }
}

function softDrop() {
  if (!isValid(current.x, current.y + 1, currentShape())) {
    lockPiece();
  } else {
    current.y++;
  }
}

function hardDrop() {
  while (isValid(current.x, current.y + 1, currentShape())) {
    current.y++;
  }
  lockPiece();
}

function rotate() {
  const rotations = TETROMINOES[current.type];
  const newRotation = (current.rotation + 1) % rotations.length;
  const newShape = rotations[newRotation];

  // Wall-kick offsets to try
  const kicks = [0, -1, 1, -2, 2];
  for (const kick of kicks) {
    if (isValid(current.x + kick, current.y, newShape)) {
      current.x += kick;
      current.rotation = newRotation;
      return;
    }
  }
}

// ============================================================
// Locking & line clearing
// ============================================================
function lockPiece() {
  const shape = currentShape();
  for (let r = 0; r < shape.length; r++) {
    for (let c = 0; c < shape[r].length; c++) {
      if (!shape[r][c]) continue;
      const ny = current.y + r;
      const nx = current.x + c;
      if (ny < 0) {
        triggerGameOver();
        return;
      }
      board[ny][nx] = 1;
      boardColors[ny][nx] = COLORS[current.type];
    }
  }
  clearLines();
  spawnPiece();
}

function clearLines() {
  let cleared = 0;
  for (let r = ROWS - 1; r >= 0; r--) {
    if (board[r].every(cell => cell === 1)) {
      board.splice(r, 1);
      boardColors.splice(r, 1);
      board.unshift(Array(COLS).fill(0));
      boardColors.unshift(Array(COLS).fill(null));
      cleared++;
      r++; // recheck the same row index
    }
  }
  if (cleared > 0) {
    score += SCORE_TABLE[cleared] * level;
    lines += cleared;
    level = Math.floor(lines / 10) + 1;
    updateUI();
  }
}

// ============================================================
// Game over
// ============================================================
function triggerGameOver() {
  gameOver = true;
  cancelAnimationFrame(animationId);
  showOverlay();
}

// ============================================================
// Drawing
// ============================================================
function drawBoard() {
  ctx.fillStyle = '#0a0a1a';
  ctx.fillRect(0, 0, boardCanvas.width, boardCanvas.height);

  // Locked cells
  for (let r = 0; r < ROWS; r++) {
    for (let c = 0; c < COLS; c++) {
      if (board[r][c]) {
        drawBlock(ctx, c, r, boardColors[r][c]);
      }
    }
  }

  // Ghost piece
  drawGhost();

  // Current piece
  const shape = currentShape();
  for (let r = 0; r < shape.length; r++) {
    for (let c = 0; c < shape[r].length; c++) {
      if (shape[r][c]) {
        drawBlock(ctx, current.x + c, current.y + r, COLORS[current.type]);
      }
    }
  }

  // Grid
  ctx.strokeStyle = 'rgba(255,255,255,0.05)';
  ctx.lineWidth = 0.5;
  for (let r = 0; r <= ROWS; r++) {
    ctx.beginPath();
    ctx.moveTo(0, r * BLOCK);
    ctx.lineTo(COLS * BLOCK, r * BLOCK);
    ctx.stroke();
  }
  for (let c = 0; c <= COLS; c++) {
    ctx.beginPath();
    ctx.moveTo(c * BLOCK, 0);
    ctx.lineTo(c * BLOCK, ROWS * BLOCK);
    ctx.stroke();
  }
}

function drawGhost() {
  let ghostY = current.y;
  while (isValid(current.x, ghostY + 1, currentShape())) ghostY++;
  if (ghostY === current.y) return;

  const shape = currentShape();
  for (let r = 0; r < shape.length; r++) {
    for (let c = 0; c < shape[r].length; c++) {
      if (shape[r][c]) {
        ctx.fillStyle = 'rgba(255,255,255,0.15)';
        ctx.fillRect((current.x + c) * BLOCK + 1, (ghostY + r) * BLOCK + 1, BLOCK - 2, BLOCK - 2);
      }
    }
  }
}

function drawBlock(context, col, row, color) {
  context.fillStyle = color;
  context.fillRect(col * BLOCK + 1, row * BLOCK + 1, BLOCK - 2, BLOCK - 2);

  // Highlight
  context.fillStyle = 'rgba(255,255,255,0.25)';
  context.fillRect(col * BLOCK + 1, row * BLOCK + 1, BLOCK - 2, 4);
  context.fillRect(col * BLOCK + 1, row * BLOCK + 1, 4, BLOCK - 2);

  // Shadow
  context.fillStyle = 'rgba(0,0,0,0.3)';
  context.fillRect(col * BLOCK + 1, row * BLOCK + BLOCK - 5, BLOCK - 2, 4);
  context.fillRect(col * BLOCK + BLOCK - 5, row * BLOCK + 1, 4, BLOCK - 2);
}

function drawNext() {
  nCtx.fillStyle = '#0a0a1a';
  nCtx.fillRect(0, 0, nextCanvas.width, nextCanvas.height);

  const shape = TETROMINOES[next.type][0];
  const rows = shape.length;
  const cols = shape[0].length;
  const offsetX = Math.floor((nextCanvas.width / BLOCK - cols) / 2);
  const offsetY = Math.floor((nextCanvas.height / BLOCK - rows) / 2);

  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      if (shape[r][c]) {
        drawBlock(nCtx, offsetX + c, offsetY + r, COLORS[next.type]);
      }
    }
  }
}

// ============================================================
// UI helpers
// ============================================================
function updateUI() {
  document.getElementById('score').textContent = score.toLocaleString();
  document.getElementById('level').textContent = level;
  document.getElementById('lines').textContent = lines;
}

function showOverlay() {
  const overlay = document.getElementById('overlay');
  document.getElementById('final-score').textContent = `スコア: ${score.toLocaleString()}`;
  overlay.classList.remove('hidden');
}

function hideOverlay() {
  document.getElementById('overlay').classList.add('hidden');
}

// ============================================================
// Game loop
// ============================================================
function gameLoop(timestamp) {
  if (gameOver) return;

  const delta = timestamp - lastTime;
  lastTime = timestamp;
  dropCounter += delta;

  if (dropCounter >= dropInterval(level)) {
    softDrop();
    dropCounter = 0;
  }

  drawBoard();
  drawNext();

  animationId = requestAnimationFrame(gameLoop);
}

// ============================================================
// Keyboard input
// ============================================================
document.addEventListener('keydown', (e) => {
  if (gameOver) return;
  switch (e.code) {
    case 'ArrowLeft':
      e.preventDefault();
      moveLeft();
      break;
    case 'ArrowRight':
      e.preventDefault();
      moveRight();
      break;
    case 'ArrowUp':
      e.preventDefault();
      rotate();
      break;
    case 'ArrowDown':
      e.preventDefault();
      softDrop();
      dropCounter = 0;
      break;
    case 'Space':
      e.preventDefault();
      hardDrop();
      break;
  }
});

// ============================================================
// Restart button
// ============================================================
document.getElementById('restart-btn').addEventListener('click', () => {
  initGame();
});

// ============================================================
// Start
// ============================================================
initGame();
