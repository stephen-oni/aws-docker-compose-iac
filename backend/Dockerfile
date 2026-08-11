# 1. Base Image: Use an official lightweight Python image.
# The 'slim' variant includes only the essentials, keeping the container small and fast.
FROM python:3.10-slim

# 2. Working Directory: Create a folder named /app inside the container.
# All subsequent COPY, RUN, and CMD instructions will happen inside this directory.
WORKDIR /app

# 3. Cache Optimization: Copy ONLY the requirements file first.
# Docker builds in layers. By copying just this file first, if you only change app.py later, 
# Docker will use the cached installation step, saving you minutes on rebuilds.
COPY requirements.txt .

# 4. Install Dependencies: Run pip to install Flask, MySQL connector, bcrypt, etc.
# The --no-cache-dir flag prevents pip from saving downloaded installation files, reducing image size.
RUN pip install --no-cache-dir -r requirements.txt

# 5. Source Code: Copy the rest of your backend files (like app.py) into the /app directory.
COPY . .

# 6. Network: Document that this container listens for internal traffic on Port 5000.
# This matches the port your Flask app uses and where Nginx forwards the /api/ traffic.
EXPOSE 5000

# 7. Execution: Start the Flask backend server.
# This tells Docker exactly what command to run when the container spins up.
CMD ["python", "app.py"]
