from flask import Flask, request, jsonify, session
import mysql.connector
from flask_bcrypt import Bcrypt
import os

app = Flask(__name__)
# In production, pull this from an environment variable!
app.secret_key = 'super_secret_key_change_this_in_production'
bcrypt = Bcrypt(app)

# Database configuration: Notice how 'host' pulls from the Docker environment
# It defaults to 'db' which is the name of our MySQL container in docker-compose.yml
db_config = {
    'host': os.getenv('DB_HOST', 'db'), 
    'user': 'root',
    'password': 'dev_password_123',
    'database': 'my_website_db'
}

def get_db_connection():
    """Helper function to open a database connection securely."""
    return mysql.connector.connect(**db_config)

@app.route('/api/signup', methods=['POST'])
def signup():
    """Handles new user registration via JSON and enforces 1 account per IP."""
    # Nginx sends the JSON body, we parse it here
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    # Because Nginx sits in front of Flask, request.remote_addr would always show Nginx's IP.
    # We must use the X-Real-IP header that Nginx forwards to get the actual user's IP.
    user_ip = request.headers.get('X-Real-IP', request.remote_addr)
    
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    # Security Rule 1: Check if this IP has already registered an account
    cursor.execute("SELECT * FROM users WHERE ip_address = %s", (user_ip,))
    if cursor.fetchone():
        cursor.close()
        conn.close()
        # Return a JSON error message with an HTTP 403 Forbidden status
        return jsonify({"status": "error", "message": "An account has already been created from this IP address."}), 403
        
    # Security Rule 2: Check if username is already taken
    cursor.execute("SELECT * FROM users WHERE username = %s", (username,))
    if cursor.fetchone():
        cursor.close()
        conn.close()
        return jsonify({"status": "error", "message": "Username is already taken."}), 409

    # Hash the password for secure storage
    hashed_password = bcrypt.generate_password_hash(password).decode('utf-8')
    
    try:
        cursor.execute(
            "INSERT INTO users (username, password, ip_address, failed_attempts) VALUES (%s, %s, %s, 0)", 
            (username, hashed_password, user_ip)
        )
        conn.commit()
    except mysql.connector.Error as err:
        return jsonify({"status": "error", "message": f"Database Error: {err}"}), 500
    finally:
        cursor.close()
        conn.close()
        
    # Success response
    return jsonify({"status": "success", "message": "Account created successfully"}), 201

@app.route('/api/login', methods=['POST'])
def login():
    """Handles user authentication via JSON and enforces the 3-strike rule."""
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM users WHERE username = %s", (username,))
    user = cursor.fetchone()
    
    if not user:
        cursor.close()
        conn.close()
        return jsonify({"status": "error", "message": "Invalid credentials. Please try again."}), 401

    # Security Rule: Check if the account is locked due to >= 3 failed attempts
    if user['failed_attempts'] >= 3:
        cursor.close()
        conn.close()
        return jsonify({"status": "error", "message": "Account locked due to too many failed login attempts."}), 403
        
    # Verify the hashed password
    if bcrypt.check_password_hash(user['password'], password):
        # Login success: Reset failed attempts back to 0
        cursor.execute("UPDATE users SET failed_attempts = 0 WHERE username = %s", (username,))
        conn.commit()
        
        # Create user session. A secure cookie is automatically sent back to the browser.
        session['user'] = username
        cursor.close()
        conn.close()
        
        return jsonify({"status": "success", "message": "Logged in successfully"}), 200
    else:
        # Login failed: Increment the failed attempts counter by 1
        new_attempts = user['failed_attempts'] + 1
        cursor.execute("UPDATE users SET failed_attempts = %s WHERE username = %s", (new_attempts, username))
        conn.commit()
        
        cursor.close()
        conn.close()
        return jsonify({"status": "error", "message": f"Invalid credentials. Failed attempts: {new_attempts}/3"}), 401

@app.route('/api/user', methods=['GET'])
def get_user():
    """Validates the active session for the frontend dashboard."""
    # The frontend calls this silently when home.html loads
    if 'user' in session:
        return jsonify({"status": "success", "username": session['user']}), 200
    
    return jsonify({"status": "error", "message": "Not authenticated"}), 401

@app.route('/api/logout', methods=['POST'])
def logout():
    """Destroys the session securely."""
    session.pop('user', None)
    return jsonify({"status": "success", "message": "Logged out successfully"}), 200

if __name__ == '__main__':
    # Run the API on port 5000. 
    # Nginx in Container 1 will forward requests to this port.
    app.run(host='0.0.0.0', port=5000, debug=True)