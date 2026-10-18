import { useParams, useLocation } from 'react-router-dom'
import RoomViewer from './RoomViewer'
import { roomGlbUrl } from './api'

export default function RoomViewerPage() {
  const { id } = useParams()
  const { state } = useLocation()
  const roomName = state?.roomName || `Room ${id}`

  return (
    <div className="viewer-page">
      <RoomViewer
        roomId={parseInt(id)}
        glbUrl={roomGlbUrl(parseInt(id))}
        roomName={roomName}
      />
    </div>
  )
}
