
# syntax=docker/dockerfile:1
ARG NODE_VERSION=20.19-alpine

# ── Build stage ──────────────────────────────────────
FROM node:${NODE_VERSION} AS builder

WORKDIR /app

COPY package*.json ./
COPY prisma ./prisma
COPY prisma.config.ts ./prisma.config.ts
RUN npm ci

COPY . .
RUN npx prisma generate && npm run build && npm prune --omit=dev

# ── Production stage ─────────────────────────────────
FROM node:${NODE_VERSION}

WORKDIR /app

COPY package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/prisma.config.ts ./prisma.config.ts

EXPOSE 3000

CMD ["node", "dist/src/main.js"]
