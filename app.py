from flask import Flask, render_template, request, redirect, url_for, session
from werkzeug.security import generate_password_hash, check_password_hash
from database import SessionLocal, Organization

# direct import
from database import SessionLocal, Organization, Item, Request, TransactionHistory, init_db


app = Flask(__name__)

# Required for session management (login/logout cookies)
app.secret_key = "supplidar_secret_key_hacktn26"


# ----------------------------------------------------
# Database Session Helper
# ----------------------------------------------------
# Every request handled seperatly.
def get_db():
    if SessionLocal:
        db = SessionLocal()
        try:
            return db
        except Exception:
            return None
    return None



# ----------------------------------------------------
# 1. Landing Page (Index)
# ----------------------------------------------------
@app.route('/')
def home():
    return render_template('index.html')

# ----------------------------------------------------
# 2. Search & Sorting Feed Page
# ----------------------------------------------------
@app.route('/items')
@app.route('/sorting')
def sorting_feed():
    return render_template('sorting.html')

# ----------------------------------------------------
# 3. Profile & Dashboard Page
# ----------------------------------------------------
@app.route('/profile')
def profile():
    return render_template('profile.html')

# ----------------------------------------------------
# 4. Authentication Pages (Login & Signup)
# ----------------------------------------------------

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        # Placeholder for authentication logic
        email = request.form.get('email')
        password = request.form.get('password')

        db = SessionLocal()
        try:
            user = db.query(Organization).filter(Organization.email == email).first()
            # Verify user exists and password hash matches
            if user and check_password_hash(user.password_hash, password):
                session['user_id'] = user.id
                session['user_name'] = user.name
                return redirect(url_for('profile'))
            else:
                return render_template('login.html', error="Invalid email or password.")

        finally:
                db.close()

    return render_template('login.html')

# loguot

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('home'))



# signup
# ----------------------------------------------------
@app.route('/signup', methods=['GET', 'POST'])
@app.route('/register', methods=['GET', 'POST'])
def signup():
    if request.method == 'POST':
        email = request.form.get('email')
        password = request.form.get('password')
        org_name = request.form.get('org_name', 'My Organization')
        account_type = request.form.get('account_type', 'donor')

        db = SessionLocal()

        try:
            # Check if email already exists
            existing_user = db.query(Organization).filter(Organization.email == email).first()
            if existing_user:
                return render_template('signup.html', error="Email is already registered. Please login.")

                # Hash password and create user
                hashed_pw = generate_password_hash(password)
                new_org = Organization(
                    name=org_name,
                    email=email,
                    password_hash=hashed_pw,
                    org_type=account_type
                )
                db.add(new_org)
                db.commit()

                # Store user info in session
                session['user_id'] = new_org.id
                session['user_name'] = new_org.name

                return redirect(url_for('profile'))
        finally:
            db.close()

        return render_template('signup.html')





        # Placeholder for account creation logic
        return redirect(url_for('profile'))
    return render_template('signup.html')

# ----------------------------------------------------
# 5. Secondary Profile Sections
# ----------------------------------------------------
@app.route('/inventory')
def inventory():
    return render_template('profile.html')

@app.route('/scanned-rooms')
def scanned_rooms():
    return render_template('profile.html')

if __name__ == '__main__':
    init_db() # Auto-creates all tables in OCI MySQL if missing
    app.run(debug=True, host='127.0.0.1', port=5000)
