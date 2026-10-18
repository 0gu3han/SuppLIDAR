from flask import Flask, render_template, request, redirect, url_for, session, flash
from werkzeug.security import generate_password_hash, check_password_hash
from database import SessionLocal, Organization, Item, ScannedRoom, init_db


app = Flask(__name__)

# Required for session management (login/logout cookies)
app.secret_key = "supplidar_secret_key_hacktn26"


# ----------------------------------------------------
# Helper: current logged-in user
# ----------------------------------------------------
def get_current_user():
    """Returns the logged-in user's info as a dict, or None if not logged in."""
    user_id = session.get('user_id')
    if not user_id:
        return None
    db = SessionLocal()
    try:
        org = db.query(Organization).filter(Organization.id == user_id).first()
        if not org:
            return None
        return {
            "name": org.name,
            "email": org.email,
            "type": org.org_type,
            "logged_in": True,
        }
    finally:
        db.close()


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
# (also serves /inventory and /scanned-rooms)
# ----------------------------------------------------
@app.route('/profile')
@app.route('/inventory')
@app.route('/scanned-rooms')
def profile():
    user = get_current_user()
    if not user:
        return redirect(url_for('login'))

    db = SessionLocal()
    try:
        items = (db.query(Item)
                   .filter(Item.owner_org_id == session['user_id'])
                   .order_by(Item.created_at.desc()).all())
        inventory = [{
            "title": i.title,
            "category": i.category,
            "status": i.status,
            "created_at": i.created_at.strftime('%b %d, %Y'),
            "urgency_score": (i.custom_metadata or {}).get('urgency_score', 'N/A'),
        } for i in items]

        scans = (db.query(ScannedRoom)
                   .filter(ScannedRoom.organization_id == session['user_id'])
                   .order_by(ScannedRoom.created_at.desc()).all())
        rooms = [{
            "name": r.room_name,
            "count": r.item_count or 0,
            "date": r.created_at.strftime('%Y-%m-%d'),
            "items": [f"{d.get('count', 1)}x {d.get('name', 'Item')}" for d in (r.detected_items or [])],
        } for r in scans]
    finally:
        db.close()

    return render_template('profile.html', user=user, inventory=inventory, rooms=rooms)


# ----------------------------------------------------
# 4. Authentication Pages (Login, Logout, Signup)
# ----------------------------------------------------
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
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


@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('home'))


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
            new_org = Organization(
                name=org_name,
                email=email,
                password_hash=generate_password_hash(password),
                org_type=account_type
            )
            db.add(new_org)
            db.commit()

            flash("Account created successfully! Please log in.")
            return redirect(url_for('login'))
        except Exception:
            db.rollback()
            return render_template('signup.html', error="Something went wrong. Please try again.")
        finally:
            db.close()

    return render_template('signup.html')


if __name__ == '__main__':
    init_db()  # Creates any missing tables (existing tables are left untouched)
    app.run(debug=True, host='127.0.0.1', port=5000)
