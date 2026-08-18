# 1. Base Image: Use the official Nginx Alpine image.
FROM nginx:alpine

# 2. Cleanup: Remove default Nginx welcome page files.
RUN rm -rf /usr/share/nginx/html/*

# 3. Source Code: Copy static files (HTML, CSS, JS, images) into Nginx web root.
COPY . /usr/share/nginx/html

# 4. Configuration: Copy custom nginx.conf into the container.
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 5. Network: Document port exposure.
EXPOSE 80

# 6. Execution: Run Nginx in foreground.
CMD ["nginx", "-g", "daemon off;"]