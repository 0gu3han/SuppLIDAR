const BASE = import.meta.env.VITE_API_BASE || ''

// ── Auth ──────────────────────────────────────────────────────────────────

export async function login(email) {
  const res = await fetch(`${BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email }),
  })
  const data = await res.json().catch(() => ({ error: `HTTP ${res.status}` }))
  if (!res.ok) throw new Error(data.error || `Login failed (${res.status})`)
  return data
}

export async function register(email, name, orgType) {
  const res = await fetch(`${BASE}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, name, org_type: orgType }),
  })
  const data = await res.json().catch(() => ({ error: `HTTP ${res.status}` }))
  if (!res.ok) throw new Error(data.error || `Register failed (${res.status})`)
  return data
}

// ── Rooms ─────────────────────────────────────────────────────────────────

export async function createRoom(user_id, name, file) {
  const fd = new FormData()
  fd.append('user_id', String(user_id))
  fd.append('name', name)
  fd.append('file', file)
  const res = await fetch(`${BASE}/rooms`, { method: 'POST', body: fd })
  const data = await res.json().catch(() => ({ error: `HTTP ${res.status}` }))
  if (!res.ok) throw new Error(data.error || `Upload failed (${res.status})`)
  return data
}

export async function listRooms(user_id) {
  const qs = user_id ? `?user_id=${encodeURIComponent(user_id)}` : ''
  const res = await fetch(`${BASE}/rooms${qs}`)
  return res.json()
}

export async function deleteRoom(room_id) {
  const res = await fetch(`${BASE}/rooms/${room_id}`, { method: 'DELETE' })
  const data = await res.json().catch(() => ({ error: `HTTP ${res.status}` }))
  if (!res.ok) throw new Error(data.error || `Delete failed (${res.status})`)
  return data
}

export function roomGlbUrl(room_id) {
  return `${BASE}/rooms/${room_id}/glb`
}

// ── Anchors ───────────────────────────────────────────────────────────────

export async function listAnchors(room_id) {
  const res = await fetch(`${BASE}/anchors?room_id=${encodeURIComponent(room_id)}`)
  const data = await res.json().catch(() => ({ error: `HTTP ${res.status}` }))
  if (!res.ok) throw new Error(data.error || `listAnchors failed (${res.status})`)
  return data
}

export async function createAnchor(data) {
  const res = await fetch(`${BASE}/anchors`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  })
  const resp = await res.json().catch(() => ({ error: `HTTP ${res.status}` }))
  if (!res.ok) throw new Error(resp.error || `createAnchor failed (${res.status})`)
  return resp
}

export async function deleteAnchor(anchor_id) {
  const res = await fetch(`${BASE}/anchors/${anchor_id}`, { method: 'DELETE' })
  const data = await res.json().catch(() => ({ error: `HTTP ${res.status}` }))
  if (!res.ok) throw new Error(data.error || `deleteAnchor failed (${res.status})`)
  return data
}

export async function createObject(data) {
  const res = await fetch(`${BASE}/objects`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  })
  const resp = await res.json().catch(() => ({ error: `HTTP ${res.status}` }))
  if (!res.ok) throw new Error(resp.error || `createObject failed (${res.status})`)
  return resp
}

// ── Items (Surplus) ───────────────────────────────────────────────────────

export async function listItems({ status, orgId } = {}) {
  const params = new URLSearchParams()
  if (status) params.set('status', status)
  if (orgId)  params.set('org_id', orgId)
  const res = await fetch(`${BASE}/items?${params}`)
  const data = await res.json().catch(() => ({ error: `HTTP ${res.status}` }))
  if (!res.ok) throw new Error(data.error || `listItems failed (${res.status})`)
  return data
}

export async function updateItemStatus(item_id, status) {
  const res = await fetch(`${BASE}/items/${item_id}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ status }),
  })
  const data = await res.json().catch(() => ({ error: `HTTP ${res.status}` }))
  if (!res.ok) throw new Error(data.error || `updateItem failed (${res.status})`)
  return data
}

// ── Requests / Claims ─────────────────────────────────────────────────────

export async function listRequests(orgId, role = 'nonprofit') {
  const params = new URLSearchParams({ org_id: orgId, role })
  const res = await fetch(`${BASE}/requests?${params}`)
  const data = await res.json().catch(() => ({ error: `HTTP ${res.status}` }))
  if (!res.ok) throw new Error(data.error || `listRequests failed (${res.status})`)
  return data
}

export async function createRequest(itemId, orgId, notes = '') {
  const res = await fetch(`${BASE}/requests`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ item_id: itemId, nonprofit_org_id: orgId, notes }),
  })
  const data = await res.json().catch(() => ({ error: `HTTP ${res.status}` }))
  if (!res.ok) throw new Error(data.error || `createRequest failed (${res.status})`)
  return data
}

export async function updateRequest(reqId, status) {
  const res = await fetch(`${BASE}/requests/${reqId}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ status }),
  })
  const data = await res.json().catch(() => ({ error: `HTTP ${res.status}` }))
  if (!res.ok) throw new Error(data.error || `updateRequest failed (${res.status})`)
  return data
}
