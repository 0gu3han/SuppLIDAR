import { Link, useLocation } from 'react-router-dom'

export default function Navbar({ user, onLogout, theme, onToggleTheme }) {
  const location = useLocation()
  const onRegisterPage = location.pathname === '/register'

  return (
    <nav className="app-navbar">
      <Link to="/" className="navbar-brand">
        SuppLIDAR
      </Link>

      <div className="navbar-right">
        {user && (
          <Link to="/items" className="navbar-register">Browse Surplus</Link>
        )}
        {!user && !onRegisterPage && (
          <Link to="/register" className="navbar-register">Create account</Link>
        )}
        <button
          type="button"
          className="theme-toggle"
          onClick={onToggleTheme}
          aria-label={`Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`}
          title={`Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`}
        >
          <span className="theme-toggle-icon" aria-hidden="true">{theme === 'dark' ? '☀' : '☾'}</span>
          <span className="theme-toggle-label">{theme === 'dark' ? 'Light' : 'Dark'}</span>
        </button>
        {user && user.org_type === 'donor' && (
          <Link to="/upload" className="navbar-upload">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
              <polyline points="16 16 12 12 8 16"/><line x1="12" y1="12" x2="12" y2="21"/>
              <path d="M20.39 18.39A5 5 0 0 0 18 9h-1.26A8 8 0 1 0 3 16.3"/>
            </svg>
            <span>Upload Room</span>
          </Link>
        )}
        {user && (
          <>
            <span className="navbar-email">{user.email}</span>
            <button className="navbar-signout" onClick={onLogout}>Sign out</button>
          </>
        )}
      </div>
    </nav>
  )
}
