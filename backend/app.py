from flask import Flask, request, jsonify, session
import mysql.connector
from flask_bcrypt import Bcrypt
import os

app = Flask(__name__)

# Secret key pulled from environment variable for security
app.secret_key = os.getenv('SECRET_KEY', 'dev_super_secret_key_change_me')
bcrypt = Bcrypt(app)

# Dynamic DB config reading variables passed from docker-compose.yml / .env
db_config = {
    'host': os.getenv('DB_HOST', 'db'), 
    'user': os.getenv('DB_USER', 'root'),
    'password': os.getenv('DB_PASSWORD', 'dev_password_123'),
    'database': os.getenv('DB_NAME', 'my_website_db')
}

def get_db_connection():
    """Helper function to open a database connection securely."""
    return mysql.connector.connect(**db_config)

@app.route('/api/signup', methods=['POST'])
def signup():
    """Handles new user registration via JSON and enforces 1 account per IP."""
    data = request.get_json() or {}
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"status": "error", "message": "Username and password are required."}), 400
    
    # Use X-Real-IP forwarded by Nginx
    user_ip = request.headers.get('X-Real-IP', request.remote_addr)
    
    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Security Rule 1: Enforce 1 account per IP
        cursor.execute("SELECT id FROM users WHERE ip_address = %s", (user_ip,))
        if cursor.fetchone():
            return jsonify({"status": "error", "message": "An account has already been created from this IP address."}), 403
            
        # Security Rule 2: Enforce unique username
        cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
        if cursor.fetchone():
            return jsonify({"status": "error", "message": "Username is already taken."}), 409

        # Hash the password securely
        hashed_password = bcrypt.generate_password_hash(password).decode('utf-8')
        
        cursor.execute(
            "INSERT INTO users (username, password, ip_address, failed_attempts) VALUES (%s, %s, %s, 0)", 
            (username, hashed_password, user_ip)
        )
        conn.commit()
        return jsonify({"status": "success", "message": "Account created successfully"}), 201

    except mysql.connector.Error as err:
        return jsonify({"status": "error", "message": f"Database Error: {err}"}), 500
    finally:
        if cursor:
            cursor.close()
        if conn and conn.is_connected():
            conn.close()

@app.route('/api/login', methods=['POST'])
def login():
    """Handles user authentication via JSON and enforces the 3-strike rule."""
    data = request.get_json() or {}
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"status": "error", "message": "Username and password are required."}), 400
    
    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM users WHERE username = %s", (username,))
        user = cursor.fetchone()
        
        if not user:
            return jsonify({"status": "error", "message": "Invalid credentials. Please try again."}), 401

        # Security Rule: Account lockout check
        if user['failed_attempts'] >= 3:
            return jsonify({"status": "error", "message": "Account locked due to too many failed login attempts."}), 403
            
        # Password Verification
        if bcrypt.check_password_hash(user['password'], password):
            cursor.execute("UPDATE users SET failed_attempts = 0 WHERE username = %s", (username,))
            conn.commit()
            session['user'] = username
            return jsonify({"status": "success", "message": "Logged in successfully"}), 200
        else:
            new_attempts = user['failed_attempts'] + 1
            cursor.execute("UPDATE users SET failed_attempts = %s WHERE username = %s", (new_attempts, username))
            conn.commit()
            
            if new_attempts >= 3:
                return jsonify({"status": "error", "message": "Account locked due to too many failed login attempts."}), 403
                
            return jsonify({"status": "error", "message": f"Invalid credentials. Failed attempts: {new_attempts}/3"}), 401

    except mysql.connector.Error as err:
        return jsonify({"status": "error", "message": f"Database Error: {err}"}), 500
    finally:
        if cursor:
            cursor.close()
        if conn and conn.is_connected():
            conn.close()

@app.route('/api/user', methods=['GET'])
def get_user():
    """Validates the active session for the frontend dashboard."""
    if 'user' in session:
        return jsonify({"status": "success", "username": session['user']}), 200
    return jsonify({"status": "error", "message": "Not authenticated"}), 401

@app.route('/api/logout', methods=['POST'])
def logout():
    """Destroys the session securely."""
    session.pop('user', None)
    return jsonify({"status": "success", "message": "Logged out successfully"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)