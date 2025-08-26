# Use a small Nginx image to serve static files
FROM nginx:1.27-alpine

# Install git, fetch Hextris source into a temp dir, then copy into Nginx's html directory
RUN apk add --no-cache git \
    && rm -rf /usr/share/nginx/html/* \
    && git clone --depth=1 https://github.com/Hextris/hextris.git /tmp/hextris \
    && cp -a /tmp/hextris/* /usr/share/nginx/html/ \
    && rm -rf /tmp/hextris

EXPOSE 80