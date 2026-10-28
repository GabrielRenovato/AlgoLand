# Servidor de presença e chat do AlgoLand. Uso: docker build -t algoland-lobby . && docker run -p 8787:8787 algoland-lobby
FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY filtro.mjs servidor.mjs duelo.mjs ./
ENV PORTA=8787
EXPOSE 8787
USER node
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://127.0.0.1:8787/saude || exit 1
CMD ["node", "servidor.mjs"]
