import { useEffect, useRef, useState } from 'react'
import * as THREE from 'three'
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js'

// ── Shared renderer (one WebGL context for ALL thumbnails) ─────────────────
const W = 520, H = 292   // offscreen resolution (16:9)

let _renderer  = null
let _rafId     = null
let _t         = 0
let _thumbs    = new Map()   // id → { scene, camera, pivot, ctx, ready }
let _nextId    = 0

function ensureRenderer() {
  if (_renderer) return _renderer
  const canvas = document.createElement('canvas')
  canvas.width  = W
  canvas.height = H
  _renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false, preserveDrawingBuffer: true })
  _renderer.setPixelRatio(1)
  _renderer.setSize(W, H, false)
  _renderer.outputColorSpace   = THREE.SRGBColorSpace
  _renderer.toneMapping        = THREE.ACESFilmicToneMapping
  _renderer.toneMappingExposure = 1.1
  return _renderer
}

function startLoop() {
  if (_rafId !== null) return
  function tick() {
    _rafId = requestAnimationFrame(tick)
    _t += 0.004
    const r = _renderer
    if (!r) return
    for (const thumb of _thumbs.values()) {
      if (!thumb.ready) continue
      thumb.pivot.rotation.y = _t
      r.render(thumb.scene, thumb.camera)
      thumb.ctx.drawImage(r.domElement, 0, 0, thumb.w, thumb.h)
    }
  }
  tick()
}

function stopLoop() {
  if (_thumbs.size === 0 && _rafId !== null) {
    cancelAnimationFrame(_rafId)
    _rafId = null
  }
}

function makeScene() {
  const scene  = new THREE.Scene()
  scene.background = new THREE.Color(0x13151c)
  scene.add(new THREE.AmbientLight(0xffffff, 0.7))
  const dir = new THREE.DirectionalLight(0xffffff, 1.2)
  dir.position.set(5, 10, 7)
  scene.add(dir)
  const fill = new THREE.DirectionalLight(0x8899cc, 0.4)
  fill.position.set(-5, -3, -5)
  scene.add(fill)
  return scene
}

// ── Component ──────────────────────────────────────────────────────────────

export default function RoomThumbnail({ glbUrl }) {
  const canvasRef  = useRef()
  const [state, setState] = useState('loading')

  useEffect(() => {
    const id     = _nextId++
    const canvas = canvasRef.current
    if (!canvas) return

    // Size the 2D canvas backing store
    canvas.width  = W
    canvas.height = H
    const ctx = canvas.getContext('2d')

    ensureRenderer()

    const scene  = makeScene()
    const camera = new THREE.PerspectiveCamera(45, W / H, 0.01, 1000)
    const pivot  = new THREE.Group()
    scene.add(pivot)

    _thumbs.set(id, { scene, camera, pivot, ctx, w: W, h: H, ready: false })
    startLoop()

    const loader = new GLTFLoader()
    loader.load(
      glbUrl,
      (gltf) => {
        const model  = gltf.scene
        const box    = new THREE.Box3().setFromObject(model)
        const center = box.getCenter(new THREE.Vector3())
        const size   = box.getSize(new THREE.Vector3())
        const maxDim = Math.max(size.x, size.y, size.z)

        model.position.sub(center)
        pivot.add(model)

        const fov  = camera.fov * (Math.PI / 180)
        const dist = (maxDim / 2) / Math.tan(fov / 2) * 1.6
        camera.position.set(dist * 0.6, dist * 0.35, dist)
        camera.lookAt(0, 0, 0)
        camera.near = maxDim * 0.001
        camera.far  = maxDim * 20
        camera.updateProjectionMatrix()

        const entry = _thumbs.get(id)
        if (entry) entry.ready = true
        setState('ready')
      },
      undefined,
      () => setState('error')
    )

    return () => {
      _thumbs.delete(id)
      stopLoop()
      // Dispose scene objects to free GPU memory
      scene.traverse((obj) => {
        if (obj.geometry) obj.geometry.dispose()
        if (obj.material) {
          const mats = Array.isArray(obj.material) ? obj.material : [obj.material]
          mats.forEach((m) => {
            Object.values(m).forEach((v) => { if (v?.isTexture) v.dispose() })
            m.dispose()
          })
        }
      })
    }
  }, [glbUrl])

  return (
    <div className="room-thumb-wrap">
      <canvas ref={canvasRef} className="room-thumb-canvas" />
      <div className={`room-thumb-checkers ${state}`} aria-hidden="true">
        <span className="room-thumb-check" />
        <span className="room-thumb-check" />
        <span className="room-thumb-check" />
      </div>
      {state === 'loading' && (
        <div className="room-thumb-overlay">
          <span className="room-thumb-spinner" />
        </div>
      )}
      {state === 'error' && (
        <div className="room-thumb-overlay room-thumb-error">
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
            <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/>
          </svg>
        </div>
      )}
    </div>
  )
}
