import os
import click
from flask import Flask, send_from_directory
from flask_migrate import Migrate
from flask_cors import CORS
from models import db
from routes import bp as routes_bp


def create_app():
    DB_URL = os.environ.get(
        "DATABASE_URL",
        "mysql+pymysql://supplidar:SuppLIDAR123!@localhost:3306/supplidar"
    )
    UPLOAD_DIR = os.path.abspath(
        os.environ.get("UPLOAD_DIR", os.path.join(os.path.dirname(__file__), "uploads"))
    )
    os.makedirs(UPLOAD_DIR, exist_ok=True)

    SPA_DIR = os.path.join(os.path.dirname(__file__), "static_spa")

    app = Flask(__name__)
    CORS(app)
    app.config["SQLALCHEMY_DATABASE_URI"] = DB_URL
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
    app.config["UPLOAD_DIR"] = UPLOAD_DIR

    db.init_app(app)
    Migrate(app, db)
    app.register_blueprint(routes_bp)

    # Serve React SPA — registered AFTER blueprint so API routes win
    @app.route("/", defaults={"path": ""})
    @app.route("/<path:path>")
    def spa(path):
        full = os.path.join(SPA_DIR, path)
        if path and os.path.exists(full):
            return send_from_directory(SPA_DIR, path)
        return send_from_directory(SPA_DIR, "index.html")

    @app.cli.command("init-db")
    def init_db():
        """Drop and recreate all tables (use when schema changes)."""
        db.drop_all()
        db.create_all()
        click.echo("Database reset — all tables recreated.")

    return app


if __name__ == "__main__":
    app = create_app()
    with app.app_context():
        db.create_all()

    port = int(os.environ.get("PORT", 5001))
    app.run(host="0.0.0.0", port=port, debug=True, use_reloader=False)
