import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { register } from './api'

const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export default function RegisterPage({ onRegistered }) {
  const navigate = useNavigate()
  const [email, setEmail]       = useState('')
  const [name, setName]         = useState('')
  const [orgType, setOrgType]   = useState('donor')
  const [focused, setFocused]   = useState(false)
  const [loading, setLoading]   = useState(false)
  const [error, setError]       = useState(null)
  const [success, setSuccess]   = useState(false)

  const trimmed = email.trim()
  const isValid = emailRegex.test(trimmed) && name.trim().length > 0
  const showHint = focused || trimmed.length > 0

  async function handleSubmit(e) {
    e.preventDefault()
    if (!isValid) return
    setLoading(true)
    setError(null)
    try {
      const u = await register(trimmed, name.trim(), orgType)
      onRegistered({ ...u, org_type: orgType })
      setSuccess(true)
      setTimeout(() => navigate('/'), 1200)
    } catch (err) {
      setError(err.message || String(err))
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="auth-page">
      <div className="auth-card">
        <div className="auth-card-header">
          <div className="auth-card-logo" aria-hidden="true">
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
              <polyline points="9 22 9 12 15 12 15 22"/>
            </svg>
          </div>
          <h1 className="auth-card-title">Create your account</h1>
          <p className="auth-card-sub">Join SuppLIDAR — donate or receive surplus items</p>
        </div>

        <form className="auth-form" onSubmit={handleSubmit}>
          <div className="auth-field">
            <label className="auth-field-label" htmlFor="reg-name">Organization name</label>
            <div className="auth-input-wrap">
              <input
                id="reg-name"
                className="auth-input"
                type="text"
                placeholder="e.g. City Food Bank"
                value={name}
                onChange={(e) => setName(e.target.value)}
                required
              />
            </div>
          </div>

          <div className="auth-field">
            <label className="auth-field-label" htmlFor="reg-email">Email address</label>
            <div className={`auth-input-wrap${focused ? ' focused' : ''}${emailRegex.test(trimmed) ? ' valid' : ''}`}>
              <span className="auth-input-icon" aria-hidden="true">@</span>
              <input
                id="reg-email"
                className="auth-input"
                type="email"
                placeholder="you@example.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                onFocus={() => setFocused(true)}
                onBlur={() => setFocused(false)}
                autoComplete="email"
                required
              />
              {emailRegex.test(trimmed) && (
                <span className="auth-input-check" aria-hidden="true">✓</span>
              )}
            </div>
            {showHint && !error && (
              <p className={`auth-field-hint${trimmed.length > 0 && !emailRegex.test(trimmed) ? ' invalid' : ''}`}>
                {trimmed.length === 0
                  ? 'Enter your email address'
                  : emailRegex.test(trimmed)
                    ? 'Looks good!'
                    : 'Use a valid email format (you@example.com)'}
              </p>
            )}
          </div>

          <div className="auth-field">
            <label className="auth-field-label">Organization type</label>
            <div className="auth-org-type-row">
              {[
                { value: 'donor', label: 'Donor', sub: 'Has surplus items to donate' },
                { value: 'nonprofit', label: 'Nonprofit', sub: 'Needs items for community' },
              ].map(({ value, label, sub }) => (
                <label
                  key={value}
                  className={`auth-org-type-card${orgType === value ? ' selected' : ''}`}
                >
                  <input
                    type="radio"
                    name="orgType"
                    value={value}
                    checked={orgType === value}
                    onChange={() => setOrgType(value)}
                    style={{ display: 'none' }}
                  />
                  <strong>{label}</strong>
                  <span>{sub}</span>
                </label>
              ))}
            </div>
          </div>

          {error && <p className="auth-error" role="alert">{error}</p>}
          {success && <p className="auth-success" role="status">Account created! Redirecting…</p>}

          <button
            type="submit"
            className="auth-submit-btn"
            disabled={loading || !isValid || success}
          >
            {loading ? (
              <span className="auth-submit-inner">
                <span className="auth-spinner" />
                Creating account…
              </span>
            ) : 'Create Account'}
          </button>
        </form>

        <p className="auth-card-footer">
          Already have an account?{' '}
          <Link to="/" className="auth-card-link">Sign in</Link>
        </p>
      </div>
    </div>
  )
}
