FROM node:20-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
COPY apps/api/package.json apps/api/
RUN npm install --workspace apps/api
COPY apps/api apps/api
COPY db db
WORKDIR /app/apps/api
RUN npx prisma generate && npm install -D tsx
CMD ["npx", "tsx", "src/main.ts"]
