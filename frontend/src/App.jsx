import React, { useEffect, useState } from 'react'
import { Routes, Route, useNavigate } from 'react-router-dom'
import { login, listRooms, roomGlbUrl, deleteRoom } from './api'
import HeroBg from './HeroBg'
import RoomThumbnail from './RoomThumbnail'
import Navbar from './Navbar'
import Footer from './Footer'
import LibraryBg from './LibraryBg'
import UploadPage from './UploadPage'
import RegisterPage from './RegisterPage'
import RoomViewerPage from './RoomViewerPage'
import ItemsPage from './ItemsPage'

function getSavedTheme() {
  try {
    const saved = localStorage.getItem('supplidar_theme')
    if (saved === 'light' || saved === 'dark') return saved
  } catch {}
  return window.matchMedia?.('(prefers-color-scheme: light)').matches ? 'light' : 'dark'
}

function getSavedUser() {
  try { return JSON.parse(sessionStorage.getItem('supplidar_user')) } catch { return null }
}
function saveUser(u)  { sessionStorage.setItem('supplidar_user', JSON.stringify(u)) }
function clearUser()  { sessionStorage.removeItem('supplidar_user') }

export default function App() {
  const navigate = useNavigate()
  const [theme, setTheme]               = useState(getSavedTheme)
  const [user, setUser]                 = useState(getSavedUser)
  const [emailInput, setEmail]          = useState('')
  const [emailFocused, setEmailFocused] = useState(false)
  const [loginError, setLoginError]     = useState(null)
  const [loggingIn, setLoggingIn]       = useState(false)
  const [rooms, setRooms]               = useState([])
  const [deleteModal, setDeleteModal]   = useState(null)
  const [deleteError, setDeleteError]   = useState(null)
  const [deleting, setDeleting]         = useState(false)

  const emailTrimmed    = emailInput.trim()
  const emailLooksValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailTrimmed)
  const showEmailHint   = emailFocused || emailTrimmed.length > 0

  useEffect(() => {
    if (user) listRooms(user.user_id).then((r) => setRooms(r.rooms ?? []))
  }, [user])

  useEffect(() => {
    document.documentElement.dataset.theme = theme
    try { localStorage.setItem('supplidar_theme', theme) } catch {}
  }, [theme])

  function toggleTheme() {
    setTheme((t) => (t === 'dark' ? 'light' : 'dark'))
  }

  async function doLogin(email) {
    setLoggingIn(true); setLoginError(null)
    try {
      const u = await login(email)
      saveUser(u); setUser(u)
    } catch (err) {
      setLoginError(err.message || String(err))
    } finally {
      setLoggingIn(false)
    }
  }

  function handleLogout() {
    clearUser(); setUser(null); setRooms([]); navigate('/')
  }

  function onDeleteRoom(room) {
    setDeleteError(null)
    setDeleteModal({ room })
  }

  async function confirmDelete() {
    if (!deleteModal) return
    setDeleting(true); setDeleteError(null)
    try {
      await deleteRoom(deleteModal.room.id)
      const d = await listRooms(user.user_id)
      setRooms(d.rooms ?? [])
      setDeleteModal(null)
    } catch (err) {
      setDeleteError(err.message || 'Delete failed')
    } finally {
      setDeleting(false)
    }
  }

  return (
    <div className="app">
      <Navbar user={user} onLogout={handleLogout} theme={theme} onToggleTheme={toggleTheme} />

      <Routes>
        <Route path="/upload"   element={<UploadPage user={user} onUploaded={setRooms} />} />
        <Route path="/register" element={<RegisterPage onRegistered={(u) => { saveUser(u); setUser(u) }} />} />
        <Route path="/rooms/:id" element={<RoomViewerPage />} />
        <Route path="/items"    element={<ItemsPage user={user} />} />

        <Route path="*" element={
          <>
            {/* ── Hero ── */}
            <header className="hero-header">
              <HeroBg theme={theme} />
              <div className="hero-content">
                <h1>SuppLIDAR</h1>
                <p className="hero-subtitle">LiDAR-powered surplus exchange</p>

                {!user && (
                  <form className="login-form" onSubmit={(e) => { e.preventDefault(); if (emailTrimmed) doLogin(emailTrimmed) }}>
                    <div className={`login-input-wrap${emailFocused ? ' focused' : ''}${emailLooksValid ? ' valid' : ''}`}>
                      <span className="login-input-icon" aria-hidden="true">@</span>
                      <input
                        className="login-input"
                        type="email"
                        placeholder="your@email.com"
                        value={emailInput}
                        onChange={(e) => setEmail(e.target.value)}
                        onFocus={() => setEmailFocused(true)}
                        onBlur={() => setEmailFocused(false)}
                        required
                      />
                    </div>
                    <div className="login-actions">
                      <button className="login-btn" type="submit" disabled={loggingIn || !emailLooksValid}>
                        {loggingIn ? 'Signing in…' : 'Sign in'}
                      </button>
                    </div>
                    <div className="login-message-row" aria-live="polite">
                      {showEmailHint && !loginError && (
                        <p className={`login-hint${emailTrimmed.length > 0 && !emailLooksValid ? ' invalid' : ''}`}>
                          {emailTrimmed.length === 0
                            ? 'Enter your email to continue'
                            : emailLooksValid
                              ? 'Looks good. Ready to sign in.'
                              : 'Use a valid email format (example@domain.com)'}
                        </p>
                      )}
                      {loginError && <p className="login-error">{loginError}</p>}
                    </div>
                  </form>
                )}

                {user && (
                  <div style={{ marginTop: 16, display: 'flex', gap: 12, justifyContent: 'center' }}>
                    <button
                      className="login-btn"
                      onClick={() => navigate('/items')}
                    >
                      Browse Surplus
                    </button>
                    {user.org_type === 'donor' && (
                      <button
                        className="login-btn demo"
                        onClick={() => navigate('/upload')}
                      >
                        Upload Room
                      </button>
                    )}
                  </div>
                )}
              </div>
            </header>

            {/* ── My Rooms (donors) ── */}
            <div className="library">
              <LibraryBg theme={theme} />

              {user && rooms.length > 0 && (
                <section className="rooms">
                  <h2>My Rooms</h2>
                  <div className="rooms-grid">
                    {rooms.map((r) => (
                      <div
                        key={r.id}
                        className="room-card"
                        onClick={() => navigate(`/rooms/${r.id}`, { state: { roomName: r.name } })}
                      >
                        <RoomThumbnail glbUrl={roomGlbUrl(r.id)} />
                        <div className="room-card-footer">
                          <strong className="room-card-name">{r.name}</strong>
                          <button
                            className="room-delete-btn"
                            onClick={(e) => { e.stopPropagation(); onDeleteRoom(r) }}
                            title="Delete room"
                          >×</button>
                        </div>
                      </div>
                    ))}
                  </div>
                </section>
              )}

              {/* ── Feature cards ── */}
              <section className="demo-rooms">
                <h2>How It Works</h2>
                <div className="demo-rooms-grid" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))' }}>
                  {[
                    {
                      icon: (
                        <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="var(--secondary-dim)" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
                          <path d="M12 2L2 7l10 5 10-5-10-5z"/><path d="M2 17l10 5 10-5"/><path d="M2 12l10 5 10-5"/>
                        </svg>
                      ),
                      title: 'LiDAR Room Scan',
                      body: 'Donors scan their space with an iPhone LiDAR sensor, capturing a photo-realistic 3D model of the room.',
                    },
                    {
                      icon: (
                        <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="var(--secondary-dim)" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
                          <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/>
                          <line x1="12" y1="12" x2="12" y2="22"/><line x1="3.27" y1="6.96" x2="12" y2="12"/>
                        </svg>
                      ),
                      title: 'Tag Surplus Items',
                      body: 'Place AR anchors on furniture, equipment, and supplies. AI automatically identifies and categorises items.',
                    },
                    {
                      icon: (
                        <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="var(--secondary-dim)" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
                          <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
                          <line x1="11" y1="8" x2="11" y2="14"/><line x1="8" y1="11" x2="14" y2="11"/>
                        </svg>
                      ),
                      title: 'Nonprofits Browse & Request',
                      body: 'Nonprofits browse available surplus in 3D, see exact condition, and request what their community needs.',
                    },
                    {
                      icon: (
                        <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="var(--secondary-dim)" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
                          <polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/><polyline points="17 6 23 6 23 12"/>
                        </svg>
                      ),
                      title: 'Track Impact',
                      body: 'Follow every item from surplus to transfer. Measure CO₂ saved and community value delivered.',
                    },
                  ].map(({ icon, title, body }) => (
                    <div key={title} className="demo-room-card" style={{ cursor: 'default' }}>
                      <div className="demo-room-thumb" style={{
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        background: 'var(--surface-high)',
                      }}>
                        {icon}
                      </div>
                      <div className="demo-room-info" style={{ flexDirection: 'column', alignItems: 'flex-start', padding: '12px 14px' }}>
                        <strong style={{ marginBottom: 4 }}>{title}</strong>
                        <span className="demo-room-author" style={{ lineHeight: 1.5 }}>{body}</span>
                      </div>
                    </div>
                  ))}
                </div>
              </section>
            </div>
          </>
        } />
      </Routes>

      <Footer />

      {deleteModal && (
        <div className="modal-backdrop" onClick={() => !deleting && setDeleteModal(null)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <h3 className="modal-title">Delete Room</h3>
            <p className="modal-body">
              Delete <strong>"{deleteModal.room.name}"</strong>? This cannot be undone.
            </p>
            {deleteError && <p className="modal-error">{deleteError}</p>}
            <div className="modal-actions">
              <button className="modal-btn modal-btn-cancel" onClick={() => setDeleteModal(null)} disabled={deleting}>Cancel</button>
              <button className="modal-btn modal-btn-delete" onClick={confirmDelete} disabled={deleting}>
                {deleting ? 'Deleting…' : 'Delete'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
