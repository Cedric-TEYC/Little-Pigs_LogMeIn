FROM nginx:alpine

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY frontend /usr/share/nginx/html

USER appuser
