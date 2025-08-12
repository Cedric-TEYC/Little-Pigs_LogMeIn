FROM nginx:alpine

# Ta conf et tes assets
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY frontend /usr/share/nginx/html

# Dossiers runtime que Nginx doit pouvoir écrire
RUN mkdir -p /var/cache/nginx/client_temp /var/cache/nginx/proxy_temp \
    /var/cache/nginx/fastcgi_temp /var/cache/nginx/uwsgi_temp /var/cache/nginx/scgi_temp \
    /var/run/nginx /var/log/nginx \
 && chown -R nginx:nginx /var/cache/nginx /var/run/nginx /var/log/nginx /etc/nginx /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
