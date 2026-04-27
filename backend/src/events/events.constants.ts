export const WS_EVENTS = {
  JOIN: 'event:join',
  LEAVE: 'event:leave',
  START: 'event:start',
  END: 'event:end',
  STATUS: 'event:status',
  STARTED: 'event:started',
  ENDED: 'event:ended',
  HOST_SOFT_DISCONNECT: 'event:host_soft_disconnect',
  HOST_JOIN: 'event:host_join',
  HOST_LEAVE: 'event:host_leave',
  HOST_RECONNECTED: 'event:host_reconnected',
  USER_JOINED: 'event:user_joined',
  EVENT_COUNT: 'event:count',
  TRACK_ADD: 'track:add',
  TRACK_REMOVE: 'track:remove',
};

export const REDIS_KEYS = {
  EVENT_HOST: (eventId: string) => `event-host:${eventId}`,
  HOST_SOCKET: (eventId: string) => `host-socket:${eventId}`,
  HOST_DISCONNECT: (eventId: string) => `host-disconnect:${eventId}`,
};

export const BULL_QUEUES = {
  EVENT_TIMEOUTS: 'event-timeouts',
};

export const BULL_JOBS = {
  HOST_SOFT_TIMEOUT: 'host-soft-timeout',
  HOST_HARD_TIMEOUT: 'host-hard-timeout',
  SOFT_TIMEOUT: 5000,
  HARD_TIMEOUT: 90000,
};
