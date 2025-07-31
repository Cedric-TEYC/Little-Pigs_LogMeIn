FROM nginx:alpine

# Copier la config nginx dans le container
COPY default.conf /etc/nginx/conf.d/default.conf

# Copier le contenu du dossier frontend dans le dossier web de nginx
COPY ../frontend /usr/share/nginx/html
