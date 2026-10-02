'use strict';

/* Process entrypoint: loads config (fails fast on missing secrets) and
 * listens. `node src/server.js` / `npm start`. */

const { config } = require('./config');
const { createApp } = require('./index');

const app = createApp({ config });

app.listen(config.port, () => {
  // eslint-disable-next-line no-console
  console.log(`ucp community api listening on :${config.port}`);
});
