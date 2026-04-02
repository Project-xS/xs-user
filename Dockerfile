FROM caddy:2-alpine

COPY deploy/caddy/Caddyfile /etc/caddy/Caddyfile

COPY deploy/install /srv/install

COPY build/web /srv/app

EXPOSE 8080
