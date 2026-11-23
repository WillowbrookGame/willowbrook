FROM node:24-bookworm-slim
WORKDIR /app
COPY LICENSE LICENSING.md ./

# Only the authored server tree and the external game data resources it reads.
COPY --chown=node:node game/network/browser/ game/network/browser/
COPY --chown=node:node game/scavenger/spots.json game/scavenger/spots.json
COPY --chown=node:node game/vehicles/side_driveways.json game/vehicles/side_driveways.json
COPY --chown=node:node deploy/*.mjs deploy/
RUN mkdir -p /var/lib/willowbrook-family-desk-container /web && \
    chown node:node /var/lib/willowbrook-family-desk-container && \
    chmod 0700 /var/lib/willowbrook-family-desk-container

USER node
STOPSIGNAL SIGINT
ENTRYPOINT ["node", "/app/deploy/start-container.mjs"]
