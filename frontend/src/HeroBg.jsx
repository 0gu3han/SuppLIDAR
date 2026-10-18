// src/HeroBg.jsx — Animated Three.js background with floating concept labels
import { useEffect, useRef } from 'react'
import * as THREE from 'three'
import { CSS2DRenderer, CSS2DObject } from 'three/examples/jsm/renderers/CSS2DRenderer'

const SHAPE_COUNT = 30

const SHAPE_DEFS = [
  { make: () => new THREE.BoxGeometry(1, 1, 1),          minS: 0.30, maxS: 0.95 },
  { make: () => new THREE.OctahedronGeometry(0.6),       minS: 0.35, maxS: 1.05 },
  { make: () => new THREE.TetrahedronGeometry(0.7),      minS: 0.30, maxS: 0.90 },
  { make: () => new THREE.IcosahedronGeometry(0.5, 0),   minS: 0.35, maxS: 1.00 },
]

// Labels attached to specific shape indices — explain the memory palace idea
const SHAPE_LABELS = {
  3:  { text: 'Spatial Anchor', sub: 'Pin any location in 3D space' },
  14: { text: 'Memory Palace',  sub: 'Walk through your knowledge' },
  24: { text: 'Place & Learn',  sub: 'Encode info into physical space' },
}

function rand(min, max) { return min + Math.random() * (max - min) }

export default function HeroBg({ theme = 'dark' }) {
  const canvasRef = useRef()
  const labelRef  = useRef()

  useEffect(() => {
    const canvas         = canvasRef.current
    const labelContainer = labelRef.current
    if (!canvas || !labelContainer) return

    // ── WebGL Renderer ───────────────────────────────────────────────────────
    const isLightTheme = theme === 'light'
    const fogColor = isLightTheme ? 0xd5deea : 0x0a0e14
    const primaryLight = isLightTheme ? 0x5965bc : 0xa8b4ff
    const secondaryLight = isLightTheme ? 0x3f968d : 0x5de8d8

    const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true })
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
    renderer.setClearColor(0x000000, 0)

    // ── CSS2D Renderer (label layer) ─────────────────────────────────────────
    const labelRenderer = new CSS2DRenderer({ element: labelContainer })
    labelRenderer.domElement.style.position = 'absolute'
    labelRenderer.domElement.style.top      = '0'
    labelRenderer.domElement.style.pointerEvents = 'none'

    // ── Scene / Camera ───────────────────────────────────────────────────────
    const scene  = new THREE.Scene()
    scene.fog = new THREE.FogExp2(fogColor, isLightTheme ? 0.056 : 0.06)
    const camera = new THREE.PerspectiveCamera(55, 1, 0.1, 100)
    camera.position.z = 5

    // ── Lights ───────────────────────────────────────────────────────────────
    scene.add(new THREE.AmbientLight(0xffffff, isLightTheme ? 0.33 : 0.6))
    const pt = new THREE.PointLight(primaryLight, isLightTheme ? 4.7 : 10, 22)
    pt.position.set(3, 4, 4)
    scene.add(pt)
    const pt2 = new THREE.PointLight(secondaryLight, isLightTheme ? 2.9 : 6, 16)
    pt2.position.set(-4, -2, 3)
    scene.add(pt2)

    // ── Shapes ───────────────────────────────────────────────────────────────
    const shapes = []
    for (let i = 0; i < SHAPE_COUNT; i++) {
      const def = SHAPE_DEFS[i % SHAPE_DEFS.length]
      const geo = def.make()

      const isWire = Math.random() < 0.45
      const mat = isWire
        ? new THREE.MeshStandardMaterial({
            color: primaryLight,
            wireframe: true,
            opacity: rand(isLightTheme ? 0.2 : 0.55, isLightTheme ? 0.4 : 0.85),
            transparent: true,
          })
        : new THREE.MeshStandardMaterial({
            color: i % 3 === 0 ? primaryLight : i % 3 === 1 ? (isLightTheme ? 0x6d7bd0 : 0x7b9fff) : secondaryLight,
            roughness: 0.3,
            metalness: 0.7,
            opacity: rand(isLightTheme ? 0.12 : 0.35, isLightTheme ? 0.28 : 0.65),
            transparent: true,
          })

      const mesh = new THREE.Mesh(geo, mat)
      const s = rand(def.minS, def.maxS)
      mesh.scale.setScalar(s)
      mesh.position.set(rand(-9, 9), rand(-5, 5), rand(-5, 1))
      mesh.rotation.set(rand(0, Math.PI * 2), rand(0, Math.PI * 2), rand(0, Math.PI * 2))

      mesh.userData = {
        vy:       rand(-0.001, 0.001),
        vx:       rand(-0.0006, 0.0006),
        rx:       rand(0.0005, 0.002) * (Math.random() < 0.5 ? 1 : -1),
        ry:       rand(0.0008, 0.003) * (Math.random() < 0.5 ? 1 : -1),
        rz:       rand(0.0003, 0.0015) * (Math.random() < 0.5 ? 1 : -1),
        bobAmp:   rand(0.04, 0.10),
        bobFreq:  rand(0.12, 0.35),
        bobPhase: rand(0, Math.PI * 2),
        originY:  mesh.position.y,
      }

      // Attach label if this shape index has one
      if (SHAPE_LABELS[i]) {
        const { text, sub } = SHAPE_LABELS[i]
        const div = document.createElement('div')
        div.className = 'shape-label'
        div.innerHTML = `<span class="shape-label-title">${text}</span><span class="shape-label-sub">${sub}</span>`
        const label = new CSS2DObject(div)
        label.position.set(0, 0.9, 0)
        mesh.add(label)
      }

      scene.add(mesh)
      shapes.push(mesh)
    }

    // ── Resize ───────────────────────────────────────────────────────────────
    function resize() {
      const w = canvas.parentElement?.clientWidth  || window.innerWidth
      const h = canvas.parentElement?.clientHeight || 220
      renderer.setSize(w, h, false)
      labelRenderer.setSize(w, h)
      camera.aspect = w / h
      camera.updateProjectionMatrix()
    }
    resize()
    window.addEventListener('resize', resize)

    // ── Render loop ──────────────────────────────────────────────────────────
    let raf
    const clock = new THREE.Clock()

    function tick() {
      raf = requestAnimationFrame(tick)
      const t = clock.getElapsedTime()

      shapes.forEach((mesh) => {
        const d = mesh.userData
        mesh.position.y = d.originY + Math.sin(t * d.bobFreq + d.bobPhase) * d.bobAmp
        mesh.position.x += d.vx
        mesh.position.y += d.vy
        if (mesh.position.x > 10) mesh.position.x = -10
        if (mesh.position.x < -10) mesh.position.x =  10
        if (mesh.position.y >  6) { mesh.position.y = -6; mesh.userData.originY = -6 }
        if (mesh.position.y < -6) { mesh.position.y =  6; mesh.userData.originY =  6 }
        mesh.rotation.x += d.rx
        mesh.rotation.y += d.ry
        mesh.rotation.z += d.rz
      })

      pt.position.x = Math.sin(t * 0.08) * 5
      pt.position.y = Math.cos(t * 0.06) * 3

      renderer.render(scene, camera)
      labelRenderer.render(scene, camera)
    }
    tick()

    return () => {
      cancelAnimationFrame(raf)
      window.removeEventListener('resize', resize)
      shapes.forEach((m) => { m.geometry.dispose(); m.material.dispose() })
      renderer.dispose()
    }
  }, [theme])

  return (
    <div className="hero-bg-wrapper">
      <canvas ref={canvasRef} className="hero-bg-canvas" aria-hidden="true" />
      <div ref={labelRef} className="hero-label-layer" aria-hidden="true" />
    </div>
  )
}
