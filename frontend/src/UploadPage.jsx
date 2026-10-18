import { useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { createRoom, listRooms } from './api'

function formatSize(bytes) {
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

export default function UploadPage({ user, onUploaded }) {
  const navigate = useNavigate()
  const [roomName, setRoomName]         = useState('')
  const [selectedFile, setSelectedFile] = useState(null)
  const [dragOver, setDragOver]         = useState(false)
  const [uploading, setUploading]       = useState(false)
  const fileRef = useRef()

  function handleDragOver(e)  { e.preventDefault(); setDragOver(true) }
  function handleDragLeave(e) { if (!e.currentTarget.contains(e.relatedTarget)) setDragOver(false) }
  function handleDrop(e)      { e.preventDefault(); setDragOver(false); const f = e.dataTransfer.files[0]; if (f) setSelectedFile(f) }
  function handleFileChange(e){ setSelectedFile(e.target.files[0] ?? null) }
  function clearFile(e)       { e.stopPropagation(); setSelectedFile(null); fileRef.current.value = '' }

  async function onUpload() {
    if (!user)         { alert('Please sign in first'); return }
    if (!selectedFile) { alert('Pick a GLB / USDZ file'); return }
    setUploading(true)
    try {
      const result = await createRoom(user.user_id, roomName.trim() || 'My Room', selectedFile)
      if (result.error) { alert(`Upload failed: ${result.error}`); return }
      const roomsData = await listRooms(user.user_id)
      onUploaded(roomsData.rooms ?? [])
      navigate('/')
    } catch (error) {
      alert(`Upload failed: ${error.message}`)
    } finally {
      setUploading(false)
    }
  }

  if (!user) {
    return (
      <div className="upload-page-gate">
        <p>Sign in to upload a room.</p>
      </div>
    )
  }

  return (
    <section className="upload-section">
      <div className="upload-card">
        <div className="upload-card-header">
          <span className="upload-card-title">Upload Room</span>
          <div className="upload-format-badges">
            {['GLB', 'GLTF', 'USDZ', 'OBJ'].map((f) => (
              <span key={f} className="format-badge">{f}</span>
            ))}
          </div>
        </div>

        <div className="upload-body">
          <input
            className="upload-name-input"
            placeholder="Room name"
            value={roomName}
            onChange={(e) => setRoomName(e.target.value)}
          />

          <div
            className={`upload-dropzone${dragOver ? ' dragover' : ''}${selectedFile ? ' has-file' : ''}`}
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
            onClick={() => fileRef.current.click()}
          >
            <input
              ref={fileRef}
              type="file"
              accept=".glb,.gltf,.obj,.usdz"
              style={{ display: 'none' }}
              onChange={handleFileChange}
            />
            {selectedFile ? (
              <div className="upload-file-selected">
                <div className="upload-file-icon">
                  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/>
                  </svg>
                </div>
                <div className="upload-file-info">
                  <div className="upload-file-name">{selectedFile.name}</div>
                  <div className="upload-file-size">{formatSize(selectedFile.size)}</div>
                </div>
                <button className="upload-file-clear" onClick={clearFile} title="Remove file">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
                    <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
                  </svg>
                </button>
              </div>
            ) : (
              <div className="upload-dropzone-prompt">
                <div className="upload-dropzone-icon">
                  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                    <polyline points="16 16 12 12 8 16"/><line x1="12" y1="12" x2="12" y2="21"/>
                    <path d="M20.39 18.39A5 5 0 0 0 18 9h-1.26A8 8 0 1 0 3 16.3"/>
                  </svg>
                </div>
                <div className="upload-dropzone-text">Drop your 3D file here</div>
                <div className="upload-dropzone-sub">or click to browse</div>
              </div>
            )}
          </div>

          <button
            className="upload-submit-btn"
            onClick={onUpload}
            disabled={uploading || !selectedFile}
          >
            {uploading ? (
              <span className="upload-submit-inner">
                <span className="upload-spinner" />
                Uploading…
              </span>
            ) : 'Upload Room'}
          </button>
        </div>
      </div>
    </section>
  )
}
