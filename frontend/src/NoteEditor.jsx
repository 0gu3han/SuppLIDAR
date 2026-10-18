// src/NoteEditor.jsx  —  inline note-creation/editing panel
import React, { useEffect, useRef } from 'react'

/**
 * Props
 *  anchorLabel  – shown in the header
 *  title        – controlled value
 *  body         – controlled value
 *  saving       – bool, disables controls while request is in flight
 *  onTitleChange / onBodyChange
 *  onSave / onCancel
 */
export default function NoteEditor({
  anchorLabel,
  title,
  body,
  saving,
  onTitleChange,
  onBodyChange,
  onSave,
  onCancel,
}) {
  const titleRef = useRef(null)

  // Auto-focus the title field when the editor opens
  useEffect(() => { titleRef.current?.focus() }, [])

  function handleKeyDown(e) {
    if (e.key === 'Escape') onCancel()
    // Ctrl/Cmd+Enter submits from either field
    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') onSave()
  }

  return (
    <div className="note-editor" onKeyDown={handleKeyDown}>
      <div className="note-editor-header">
        <div className="note-editor-header-left">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"/>
          </svg>
          <span>New note — <em>{anchorLabel}</em></span>
        </div>
        <button className="note-editor-close" onClick={onCancel} title="Cancel (Esc)">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
            <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
          </svg>
        </button>
      </div>

      <div className="note-editor-field">
        <label>Title</label>
        <input
          ref={titleRef}
          value={title}
          onChange={(e) => onTitleChange(e.target.value)}
          placeholder="e.g. Mitochondria function"
          disabled={saving}
        />
      </div>

      <div className="note-editor-field">
        <label>Note / mnemonic</label>
        <textarea
          value={body}
          onChange={(e) => onBodyChange(e.target.value)}
          placeholder="Write your mnemonic, summary, or memory cue here…"
          rows={4}
          disabled={saving}
        />
      </div>

      <div className="note-editor-actions">
        <span className="note-editor-hint">Ctrl+Enter to save</span>
        <button className="note-editor-cancel" onClick={onCancel} disabled={saving}>
          Cancel
        </button>
        <button
          className="note-editor-save"
          onClick={onSave}
          disabled={saving || !title.trim()}
        >
          {saving ? 'Saving…' : 'Save note'}
        </button>
      </div>
    </div>
  )
}
