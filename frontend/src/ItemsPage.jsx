import { useEffect, useState } from 'react'
import { listItems, updateItemStatus, createRequest } from './api'

const STATUS_COLORS = {
  surplus:     'var(--secondary-dim)',
  in_use:      'var(--secondary)',
  not_in_use:  'var(--primary)',
  claimed:     '#f59e0b',
  transferred: 'var(--on-surface-dim)',
}

function StatusBadge({ status }) {
  const color = STATUS_COLORS[status] || 'var(--secondary)'
  const label = status.replace(/_/g, ' ')
  return (
    <span style={{
      fontSize: '0.65rem', fontWeight: 600, letterSpacing: '0.05em',
      textTransform: 'uppercase', padding: '3px 8px', borderRadius: '999px',
      background: color + '22', color, border: `1px solid ${color}44`,
    }}>
      {label}
    </span>
  )
}

export default function ItemsPage({ user }) {
  const [items, setItems]         = useState([])
  const [loading, setLoading]     = useState(true)
  const [search, setSearch]       = useState('')
  const [statusFilter, setFilter] = useState('surplus')
  const [requesting, setRequesting] = useState(null)
  const [requestNote, setRequestNote] = useState('')
  const [error, setError]         = useState(null)

  useEffect(() => {
    setLoading(true)
    listItems({ status: statusFilter || undefined })
      .then((d) => setItems(d.items ?? []))
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false))
  }, [statusFilter])

  const isDonor = user?.org_type === 'donor'

  const filtered = items.filter((it) => {
    const q = search.toLowerCase()
    return !q || it.name?.toLowerCase().includes(q) || it.category?.toLowerCase().includes(q)
  })

  async function handleRequest(item) {
    if (!user) { alert('Sign in first'); return }
    setRequesting(item)
    setRequestNote('')
  }

  async function submitRequest() {
    if (!requesting || !user) return
    try {
      await createRequest(requesting.id, user.org_id ?? user.user_id, requestNote)
      setRequesting(null)
      // Refresh items
      const d = await listItems({ status: statusFilter || undefined })
      setItems(d.items ?? [])
    } catch (e) {
      alert(e.message)
    }
  }

  async function handleStatusChange(item, newStatus) {
    try {
      await updateItemStatus(item.id, newStatus)
      const d = await listItems({ status: statusFilter || undefined })
      setItems(d.items ?? [])
    } catch (e) {
      alert(e.message)
    }
  }

  return (
    <div className="library" style={{ minHeight: '60vh', paddingTop: '2rem' }}>
      <section className="rooms" style={{ maxWidth: 1100, margin: '0 auto', padding: '0 24px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginBottom: 24, flexWrap: 'wrap' }}>
          <h2 style={{ margin: 0, flex: 1 }}>Surplus Items</h2>
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search items…"
            style={{
              background: 'var(--surface-container)', border: '1px solid var(--outline-variant)',
              borderRadius: 8, padding: '8px 14px', color: 'var(--on-surface)',
              fontSize: '0.85rem', width: 200,
            }}
          />
          <select
            value={statusFilter}
            onChange={(e) => setFilter(e.target.value)}
            style={{
              background: 'var(--surface-container)', border: '1px solid var(--outline-variant)',
              borderRadius: 8, padding: '8px 12px', color: 'var(--on-surface)', fontSize: '0.85rem',
            }}
          >
            <option value="">All statuses</option>
            <option value="surplus">Surplus</option>
            <option value="in_use">In use</option>
            <option value="not_in_use">Not in use</option>
            <option value="claimed">Claimed</option>
            <option value="transferred">Transferred</option>
          </select>
        </div>

        {error && <p style={{ color: 'var(--secondary-dim)' }}>{error}</p>}

        {loading ? (
          <div style={{ textAlign: 'center', padding: '3rem', color: 'var(--on-surface-dim)' }}>
            <div className="upload-spinner" style={{ margin: '0 auto 12px' }} />
            Loading items…
          </div>
        ) : filtered.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '3rem', color: 'var(--on-surface-dim)' }}>
            No items found.
          </div>
        ) : (
          <div className="rooms-grid">
            {filtered.map((item) => (
              <div key={item.id} className="room-card" style={{ cursor: 'default' }}>
                <div style={{
                  height: 140, background: 'var(--surface-high)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  borderRadius: '8px 8px 0 0', overflow: 'hidden',
                }}>
                  {item.photo_url ? (
                    <img
                      src={item.photo_url}
                      alt={item.name || item.title}
                      style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                      onError={(e) => { e.target.style.display = 'none'; e.target.nextSibling.style.display = 'flex' }}
                    />
                  ) : null}
                  <div style={{
                    display: item.photo_url ? 'none' : 'flex',
                    width: '100%', height: '100%',
                    alignItems: 'center', justifyContent: 'center',
                  }}>
                    <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="var(--outline-variant)" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
                      <rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/>
                      <polyline points="21 15 16 10 5 21"/>
                    </svg>
                  </div>
                </div>
                <div className="room-card-footer" style={{ flexDirection: 'column', alignItems: 'flex-start', gap: 6, padding: '10px 12px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, width: '100%' }}>
                    <strong className="room-card-name" style={{ flex: 1, fontSize: '0.9rem' }}>
                      {item.name || item.title || 'Unnamed item'}
                    </strong>
                    <StatusBadge status={item.status} />
                  </div>
                  {item.category && (
                    <span style={{ fontSize: '0.75rem', color: 'var(--on-surface-dim)' }}>{item.category}</span>
                  )}
                  {item.description && (
                    <span style={{ fontSize: '0.75rem', color: 'var(--on-surface-dim)', lineHeight: 1.4 }}>
                      {item.description.length > 80 ? item.description.slice(0, 80) + '…' : item.description}
                    </span>
                  )}
                  <div style={{ display: 'flex', gap: 8, marginTop: 4, width: '100%' }}>
                    {!isDonor && item.status === 'surplus' && (
                      <button
                        onClick={() => handleRequest(item)}
                        style={{
                          flex: 1, padding: '6px 0', fontSize: '0.75rem', fontWeight: 600,
                          background: 'var(--primary)', color: '#fff', border: 'none',
                          borderRadius: 6, cursor: 'pointer',
                        }}
                      >
                        Request Item
                      </button>
                    )}
                    {isDonor && !['claimed', 'transferred'].includes(item.status) && (
                      <select
                        value={item.status}
                        onChange={(e) => handleStatusChange(item, e.target.value)}
                        style={{
                          flex: 1, padding: '5px 8px', fontSize: '0.75rem',
                          background: 'var(--surface-high)', border: '1px solid var(--outline-variant)',
                          borderRadius: 6, color: 'var(--on-surface)', cursor: 'pointer',
                        }}
                      >
                        <option value="in_use">In use</option>
                        <option value="not_in_use">Not in use</option>
                        <option value="surplus">Surplus</option>
                      </select>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </section>

      {/* Request modal */}
      {requesting && (
        <div className="modal-backdrop" onClick={() => setRequesting(null)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <h3 className="modal-title">Request Item</h3>
            <p className="modal-body">
              Request <strong>"{requesting.name || requesting.title}"</strong> for your organization.
            </p>
            <textarea
              value={requestNote}
              onChange={(e) => setRequestNote(e.target.value)}
              placeholder="Notes (optional) — describe your use case…"
              rows={3}
              style={{
                width: '100%', boxSizing: 'border-box', background: 'var(--surface-high)',
                border: '1px solid var(--outline-variant)', borderRadius: 8,
                color: 'var(--on-surface)', padding: '10px 12px', fontSize: '0.85rem',
                resize: 'vertical', marginBottom: 12,
              }}
            />
            <div className="modal-actions">
              <button className="modal-btn modal-btn-cancel" onClick={() => setRequesting(null)}>Cancel</button>
              <button className="modal-btn modal-btn-delete" style={{ background: 'var(--primary)' }} onClick={submitRequest}>
                Submit Request
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
