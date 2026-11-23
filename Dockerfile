FROM node:24-bookworm-slim
WORKDIR /app
COPY LICENSE LICENSING.md ./

# Only the authored server tree and the external game data resources it reads.
COPY --chown=node:node paintball_prototype/network/browser/ paintball_prototype/network/browser/
COPY --chown=node:node paintball_prototype/scavenger/spots.json paintball_prototype/scavenger/spots.json
COPY --chown=node:node paintball_prototype/vehicles/side_driveways.json paintball_prototype/vehicles/side_driveways.json
COPY --chown=node:node deploy/*.mjs deploy/
RUN mkdir -p /var/lib/willowbrook-family-desk-container /web && \
    chown node:node /var/lib/willowbrook-family-desk-container && \
    chmod 0700 /var/lib/willowbrook-family-desk-container

USER node
STOPSIGNAL SIGINT
ENTRYPOINT ["node", "/app/paintball_prototype/network/browser/server.mjs"]
