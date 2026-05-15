export const INTERNAL_EVENTS = {
  DELEGATION_INVITE_SENT: 'delegation.invite_sent',
};

export const MAX_VOTES_PER_EVENT = 100;

export const WS_EVENTS = {
  // LISTENER EVENTS
  JOIN: 'event:join',
  LEAVE: 'event:leave',
  START: 'event:start',
  END: 'event:end',
  PLAYBACK_PLAY: 'playback:play',
  PLAYBACK_PAUSE: 'playback:pause',
  PLAYBACK_NEXT: 'playback:next',
  HOST_JOIN: 'event:host_join',
  HOST_LEAVE: 'event:host_leave',
  TRACK_VOTE: 'track:vote',
  DELEGATION_RESPONSE: 'event:delegation-response',

  // EMITTED EVENTS
  STATUS: 'event:status',
  STARTED: 'event:started',
  ENDED: 'event:ended',
  HOST_SOFT_DISCONNECT: 'event:host_soft_disconnect',
  HOST_RECONNECTED: 'event:host_reconnected',
  USER_JOINED: 'event:user_joined',
  EVENT_COUNT: 'event:count',
  DELEGATE: 'event:delegate',

  PLAYBACK_STATUS: 'playback:status',

  TRACK_ADDED: 'track:added',
  TRACK_REMOVED: 'track:removed',
  TRACK_VOTE_UPDATED: 'track:vote_updated',
};

export const REDIS_KEYS = {
  EVENT_HOST: (eventId: string) => `event-host:${eventId}`,
  HOST_SOCKET: (eventId: string) => `host-socket:${eventId}`,
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
