FROM nginx:alpine

# Config et statiques
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY frontend /usr/share/nginx/html

# S'assurer que Nginx peut écrire ses fichiers runtime (pid, cache, logs)
RUN mkdir -p /var/cache/nginx /var/run \
 && chown -R root:root /var/cache/nginx /var/run /var/log/nginx /etc/nginx /usr/share/nginx/html

# On reste root pour éviter les soucis "read-only" au démarrage en Swarm
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
