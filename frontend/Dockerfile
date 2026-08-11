# 1. Base Image: Use the official Nginx Alpine image.
# Alpine is a minimalist version of Linux, which keeps your container size incredibly small and fast to deploy.
FROM nginx:alpine

# 2. Cleanup: Remove the default Nginx welcome page files.
# This ensures Nginx only serves your specific PULSE FIT application and nothing else.
RUN rm -rf /usr/share/nginx/html/*

# 3. Configuration: Copy your custom nginx.conf into the container.
# This overrides the default settings so Nginx knows how to route the /api/ traffic to the backend.
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 4. Source Code: Copy all your frontend files into the Nginx serving directory.
# The '.' means "copy everything in the current frontend/ folder" (HTML, CSS, images).
COPY . /usr/share/nginx/html

# 5. Network: Document that this container listens for traffic on Port 80.
# This does not publish the port to the internet; it just exposes it to the Docker network.
EXPOSE 80

# 6. Execution: Start the Nginx server.
# 'daemon off' forces Nginx to run in the foreground, which is required to keep a Docker container alive.
CMD ["nginx", "-g", "daemon off;"]