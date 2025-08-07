FROM nginx:alpine

# Ajout user non-root pour servir les fichiers
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /usr/share/nginx/html
COPY . .

USER appuser

