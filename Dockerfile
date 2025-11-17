FROM nginx:1.27-alpine

# Copy my custom nginx config
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# Copy my HTML file into Nginxs dir
COPY nginx/index.html /usr/share/nginx/html/index.html

# Create a nonroot user (like I was asked in assignment)
RUN adduser -D -u 1001 nginxuser

# Give the nonroot user access to html folder and nginx cache folder
RUN chown -R nginxuser:nginxuser /usr/share/nginx/html /var/cache/nginx

# Allow Nginx (even as nonroot) to listen on port 80
RUN apk add --no-cache libcap && \
    setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx

# Switch to the safer nonroot user
USER nginxuser

EXPOSE 80
