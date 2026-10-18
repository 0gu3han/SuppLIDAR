import { Link } from 'react-router-dom'

export default function Footer() {
  return (
    <footer className="app-footer">
      <div className="footer-inner">
        <span className="footer-brand">SuppLIDAR</span>
        <span className="footer-sep">·</span>
        <span className="footer-tagline">Connecting surplus to community</span>
        <div className="footer-links">
          <Link to="/">Home</Link>
          <Link to="/items">Browse Surplus</Link>
          <Link to="/upload">Upload Room</Link>
        </div>
      </div>
    </footer>
  )
}
