const { io } = require('socket.io-client');

const host = process.env.WS_HOST || 'http://localhost:3000';
const path = process.env.WS_PATH || '/ws';
const roomId = process.env.WS_ROOM || 'room-123';
const trackId = process.env.WS_TRACK || 'track-456';
const vote = process.env.WS_VOTE || 'up';
const token = process.env.WS_TOKEN || '';

const socketOptions = {
  path,
  transports: ['websocket'],
};

if (token.trim().length > 0) {
  socketOptions.auth = { token };
}

const socket = io(host, socketOptions);

socket.on('connect', () => {
  console.log(`Connected: ${socket.id}`);
  socket.emit('room:join', { roomId });
  socket.emit('ping');
  socket.emit('track:vote', { roomId, trackId, vote }, (ack) => {
    if (ack) {
      console.log('Vote ack:', ack);
    }
  });
});

socket.on('disconnect', (reason) => {
  console.log('Disconnected:', reason);
});

socket.on('room:joined', (payload) => {
  console.log('Joined room:', payload);
});

socket.on('room:left', (payload) => {
  console.log('Left room:', payload);
});

socket.on('pong', (payload) => {
  console.log('Pong:', payload);
});

socket.on('track:vote_updated', (payload) => {
  console.log('Vote updated:', payload);
});

socket.on('room:error', (payload) => {
  console.error('Room error:', payload);
});

socket.on('connect_error', (err) => {
  console.error('Connection error:', err.message);
});

process.on('SIGINT', () => {
  console.log('Closing socket...');
  socket.emit('room:leave', { roomId });
  socket.disconnect();
  process.exit(0);
});
