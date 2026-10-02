'use strict';

/* In-process fan-out for live updates: every mutation broadcasts one
 * `{"type":"community-changed"}` event; connected SSE clients refetch.
 * (Single instance is all the pilot needs; Redis pub/sub if you scale
 * past one dyno.) */

const clients = new Set();

function addClient(res) {
  clients.add(res);
}

function removeClient(res) {
  clients.delete(res);
}

function broadcast() {
  const payload = 'data: {"type":"community-changed"}\n\n';
  for (const res of clients) {
    try {
      res.write(payload);
    } catch (_) {
      clients.delete(res);
    }
  }
}

function clientCount() {
  return clients.size;
}

function __reset() {
  clients.clear();
}

module.exports = { addClient, removeClient, broadcast, clientCount, __reset };
