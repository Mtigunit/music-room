/* eslint-disable no-console */
// Multi-instance Socket.io smoke test.
//
// Goal: verify that room broadcasts traverse Redis adapter across two backend instances.
//
// Usage (PowerShell):
//   $env:WS_TOKEN="<jwt>"; $env:WS_HOST_A="http://localhost:3000"; $env:WS_HOST_B="http://localhost:3001"; npm run ws:multi
//
// Prereq: run two backend instances pointing at the same Redis.

const { io } = require('socket.io-client');

const hostA = process.env.WS_HOST_A || 'http://localhost:3000';
const hostB = process.env.WS_HOST_B || 'http://localhost:3001';
const path = process.env.WS_PATH || '/ws';
const roomId = process.env.WS_ROOM || 'room-123';
const trackId = process.env.WS_TRACK || 'track-456';
const vote = process.env.WS_VOTE || 'up';
const token = (process.env.WS_TOKEN || '').trim();

const timeoutMs = Number(process.env.WS_TIMEOUT_MS || '8000');

if (!token) {
  console.error('WS_TOKEN is required for strict handshake auth');
  process.exit(1);
}

function makeSocket(host) {
  return io(host, {
    path,
    transports: ['websocket'],
    auth: { token },
  });
}

function onceWithTimeout(socket, event, ms) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error(`Timeout waiting for ${event}`));
    }, ms);

    socket.once(event, (payload) => {
      clearTimeout(timer);
      resolve(payload);
    });
  });
}

async function joinRoom(socket, label) {
  socket.emit('room:join', { roomId });
  const payload = await onceWithTimeout(socket, 'room:joined', timeoutMs);
  if (!payload || payload.roomId !== roomId) {
    throw new Error(`${label}: unexpected room:joined payload`);
  }
}

async function bootstrap() {
  const a = makeSocket(hostA);
  const b = makeSocket(hostB);

  a.on('connect_error', (err) => console.error('[A] connect_error:', err.message));
  b.on('connect_error', (err) => console.error('[B] connect_error:', err.message));

  try {
    await Promise.all([
      onceWithTimeout(a, 'connect', timeoutMs),
      onceWithTimeout(b, 'connect', timeoutMs),
    ]);

    console.log(`Connected A: ${a.id} -> ${hostA}`);
    console.log(`Connected B: ${b.id} -> ${hostB}`);

    await Promise.all([joinRoom(a, 'A'), joinRoom(b, 'B')]);
    console.log(`Both joined room: ${roomId}`);

    const updatedOnB = onceWithTimeout(b, 'track:vote_updated', timeoutMs);

    const ack = await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('Timeout waiting for track:vote ack')), timeoutMs);
      a.emit('track:vote', { roomId, trackId, vote }, (payload) => {
        clearTimeout(timer);
        resolve(payload);
      });
    });

    const updatedPayload = await updatedOnB;

    if (!updatedPayload || updatedPayload.roomId !== roomId || updatedPayload.trackId !== trackId) {
      throw new Error('Unexpected track:vote_updated payload on B');
    }

    if (!ack || ack.roomId !== roomId || ack.trackId !== trackId) {
      throw new Error('Unexpected ack payload from track:vote');
    }

    console.log('PASS: B received track:vote_updated from room broadcast');
  } finally {
    a.disconnect();
    b.disconnect();
  }
}

bootstrap().catch((err) => {
  console.error('FAIL:', err.message);
  process.exit(1);
});
