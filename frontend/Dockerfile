FROM nginx:alpine

WORKDIR /usr/share/nginx/html
COPY . .

RUN mkdir -p /var/cache/nginx/client_temp /var/cache/nginx/proxy_temp \
    /var/cache/nginx/fastcgi_temp /var/cache/nginx/uwsgi_temp /var/cache/nginx/scgi_temp \
    /var/run/nginx /var/log/nginx \
 && chown -R nginx:nginx /var/cache/nginx /var/run/nginx /var/log/nginx /etc/nginx /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
