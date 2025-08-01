FROM nginx:alpine

# On part de la racine du repo pour le build context, donc le chemin est relatif à la racine
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY frontend /usr/share/nginx/html