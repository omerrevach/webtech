# Use official Nginx image
FROM nginx:1.27-alpine

# Set work directory
WORKDIR /usr/share/nginx/html

# Copy custom nginx config
COPY nginx/nginx.conf /etc/nginx/nginx.conf
# Copy HTML file
COPY nginx/index.html /usr/share/nginx/html/index.html

# These 2 files go into dif directories each so i cant place them
# in one copy
EXPOSE 80
