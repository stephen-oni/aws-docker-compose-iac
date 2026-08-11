from flask import Flask, render_template, request, redirect, url_for, session
import mysql.connector
from flask_bcrypt import Bcrypt

app = Flask(__name__)
app.secret_key = 'super_secret_key_change_this_in_production'
bcrypt = Bcrypt(app)

# Database configuration: Change 'host' to your RDS endpoint when deploying
db_config = {
    'host': 'localhost', 
    'user': 'root',
    'password': 'your_password_here',
    'database': 'my_website_db'
}

def get_db_connection():
    """Helper function to open a database connection securely."""
    return mysql.connector.connect(**db_config)

@app.route('/')
def index():
    """Default route pointing to the login page."""
    if 'user' in session:
        return redirect(url_for('home'))
    return render_template('index.html')

@app.route('/signup', methods=['GET', 'POST'])
def signup():
    """Handles new user registration and enforces 1 account per IP."""
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        user_ip = request.remote_addr # Grabs the user's IP address
        
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Security Rule: Check if this IP has already registered an account
        cursor.execute("SELECT * FROM users WHERE ip_address = %s", (user_ip,))
        if cursor.fetchone():
            cursor.close()
            conn.close()
            return "Registration failed: An account has already been created from this IP address."
            
        # Hash the password for secure storage
        hashed_password = bcrypt.generate_password_hash(password).decode('utf-8')
        
        try:
            cursor.execute(
                "INSERT INTO users (username, password, ip_address) VALUES (%s, %s, %s)", 
                (username, hashed_password, user_ip)
            )
            conn.commit()
        except mysql.connector.Error as err:
            return f"Database Error: {err}"
        finally:
            cursor.close()
            conn.close()
            
        return redirect(url_for('index'))
        
    return render_template('signup.html')

@app.route('/login', methods=['POST'])
def login():
    """Handles user authentication and enforces the 3-strike failed login rule."""
    username = request.form['username']
    password = request.form['password']
    
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM users WHERE username = %s", (username,))
    user = cursor.fetchone()
    
    if not user:
        cursor.close()
        conn.close()
        return "Invalid credentials. Please try again."

    # Security Rule: Check if the account is locked due to >= 3 failed attempts
    if user['failed_attempts'] >= 3:
        cursor.close()
        conn.close()
        return "Account locked due to too many failed login attempts."
        
    # Verify the hashed password
    if bcrypt.check_password_hash(user['password'], password):
        # Login success: Reset failed attempts back to 0
        cursor.execute("UPDATE users SET failed_attempts = 0 WHERE username = %s", (username,))
        conn.commit()
        
        # Create user session
        session['user'] = username
        cursor.close()
        conn.close()
        return redirect(url_for('home'))
    else:
        # Login failed: Increment the failed attempts counter by 1
        new_attempts = user['failed_attempts'] + 1
        cursor.execute("UPDATE users SET failed_attempts = %s WHERE username = %s", (new_attempts, username))
        conn.commit()
        
        cursor.close()
        conn.close()
        return f"Invalid credentials. Failed attempts: {new_attempts}/3"

@app.route('/home')
def home():
    """Protected route. Redirects to login if session does not exist."""
    if 'user' in session:
        return render_template('home.html', username=session['user'])
    return redirect(url_for('index'))

@app.route('/logout')
def logout():
    """Destroys the session and logs the user out."""
    session.pop('user', None)
    return redirect(url_for('index'))

@app.route('/about')
def about():
    """Renders the About Us page."""
    return render_template('about.html')

@app.route('/terms')
def terms():
    """Renders the Terms of Service page."""
    return render_template('terms.html')

if __name__ == '__main__':
    # Run the app. Debug=True helps spot errors during development.
    app.run(host='0.0.0.0', port=5000, debug=True)