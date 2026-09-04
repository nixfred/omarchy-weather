pragma ComponentBehavior: Bound

import QtQuick

// A slow parallax cloud deck that sits behind the forecast orbit. Each bank is
// a cluster of radial-gradient puffs, so the softness comes from the gradients
// themselves rather than from a blur effect - same trick WeatherEnergyCore
// uses, and it keeps the layer cheap enough to repaint on the ambient phase.
//
// Three rows drift at different speeds and wrap independently, which is what
// sells depth: the near deck slides visibly while the far deck barely moves.
Item {
  id: root

  property bool active: true
  property bool storm: false
  property real phase: 0
  // 0 = clear sky (a couple of wisps), 1 = fully overcast. Fed by the live
  // cloud_cover observation when the hub is showing today.
  property real density: 0.6
  // Observed wind. Speed is mph; direction is the meteorological "from"
  // bearing in degrees, exactly as Open-Meteo reports it, so 90 means an
  // easterly and the deck has to travel to the left.
  property real windSpeed: 6
  property real windFromDeg: -1
  // 0 = dry, 1 = heavy. Drives the falling layer.
  property real precip: 0
  // Frozen precipitation drifts instead of streaking.
  property bool snow: false
  property bool night: false
  property color accentColor: "#5aa9ff"
  property color urgentColor: "#ff5577"
  property color liveColor: storm ? urgentColor : accentColor

  // Screen-space wind vector. Meteorological bearings name where wind comes
  // FROM, so travel is the opposite heading; north is up, so the vertical
  // component is -cos. Without a reading, fall back to a gentle westerly.
  readonly property real windToRad: (windFromDeg >= 0 ? windFromDeg + 180 : 270) * Math.PI / 180
  readonly property real windX: Math.sin(windToRad)
  readonly property real windY: -Math.cos(windToRad)
  // Spans per second. A dead calm still creeps, a gale still resolves as
  // motion rather than a blur.
  readonly property real driftRate: Math.max(0.004, Math.min(0.075, 0.004 + windSpeed * 0.0022))
  // The deck is drawn in a washed-out version of the condition color so it
  // stays condition-aware without disappearing into a dark theme.
  readonly property color cloudTint: Qt.lighter(liveColor, root.night ? 1.45 : 1.9)

  // Horizontal travel runs on its own clock rather than the panel's ambient
  // phase. The ambient phase resets 2*PI -> 0 every loop, which would snap any
  // row whose speed is not exactly 1.0. Counting up to a round 1000 spans with
  // speeds of 1.00 / 0.58 / 0.30 means every row lands on a whole span when the
  // animation restarts, so the wrap is invisible.
  property real driftT: 0
  property real fallT: 0

  // Accumulated by frame rather than animated to a fixed endpoint: the wind
  // reading changes on every refresh, and a NumberAnimation restarts from
  // `from` whenever its duration is reassigned, which would teleport the whole
  // deck. Integrating dt keeps a wind change as a change in speed only.
  FrameAnimation {
    running: root.active
    onTriggered: {
      root.driftT += frameTime * root.driftRate
      root.fallT += frameTime
    }
  }

  opacity: active ? 1 : 0

  Behavior on opacity { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
  Behavior on density { NumberAnimation { duration: 700; easing.type: Easing.InOutCubic } }
  Behavior on liveColor { ColorAnimation { duration: 520; easing.type: Easing.OutCubic } }

  Canvas {
    id: cloudCanvas
    anchors.fill: parent
    antialiasing: true

    // Fixed table instead of Math.random(): the deck must look identical
    // every repaint, otherwise the clouds would boil instead of drift.
    // row, xSeed (0..1), ySeed (0..1), scale, speed, alpha weight
    readonly property var banks: [
      [0, 0.02, 0.14, 1.00, 1.00, 1.00],
      [0, 0.27, 0.06, 0.74, 1.00, 0.80],
      [0, 0.51, 0.21, 1.16, 1.00, 0.96],
      [0, 0.79, 0.10, 0.88, 1.00, 0.84],
      [1, 0.09, 0.48, 0.66, 0.58, 0.74],
      [1, 0.34, 0.38, 0.92, 0.58, 0.86],
      [1, 0.61, 0.55, 0.58, 0.58, 0.66],
      [1, 0.86, 0.42, 1.04, 0.58, 0.80],
      [2, 0.15, 0.78, 1.30, 0.30, 0.72],
      [2, 0.41, 0.90, 0.86, 0.30, 0.62],
      [2, 0.68, 0.72, 1.08, 0.30, 0.68],
      [2, 0.92, 0.86, 0.76, 0.30, 0.56]
    ]

    // Offsets of the puffs that make up one cloud, in units of the cloud's
    // own radius. Slightly asymmetric so no bank reads as a snowman.
    readonly property var puffs: [
      [-0.86, 0.16, 0.58],
      [-0.34, -0.12, 0.86],
      [0.18, -0.24, 1.00],
      [0.72, 0.02, 0.72],
      [1.16, 0.20, 0.48],
      [0.02, 0.26, 0.78]
    ]

    function drawCloud(ctx, cx, cy, radius, alpha) {
      for (var i = 0; i < puffs.length; i++) {
        var p = puffs[i]
        var px = cx + p[0] * radius
        var py = cy + p[1] * radius
        var pr = Math.max(1, p[2] * radius)
        var g = ctx.createRadialGradient(px, py, pr * 0.12, px, py, pr)
        // Lifted well off the accent: a saturated blue cloud on a navy panel
        // is invisible. Pushing it toward white is what makes it read as vapor.
        var c = root.cloudTint
        // A held core then a fast falloff. A single linear ramp from centre
        // to edge just produces fog; the plateau is what gives a puff a top.
        g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, alpha).toString())
        g.addColorStop(0.42, Qt.rgba(c.r, c.g, c.b, alpha * 0.90).toString())
        g.addColorStop(0.72, Qt.rgba(c.r, c.g, c.b, alpha * 0.34).toString())
        g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0).toString())
        ctx.fillStyle = g
        ctx.beginPath()
        ctx.arc(px, py, pr, 0, Math.PI * 2)
        ctx.fill()
      }
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      if (!root.active || width <= 0 || height <= 0 || root.density <= 0.01) return

      var travel = root.driftT
      // Wider than the stage so a bank is fully off-screen before it wraps.
      var span = width * 1.6
      var vspan = height * 1.6
      var margin = width * 0.3
      var vmargin = height * 0.3
      var baseRadius = Math.min(width * 0.125, height * 0.30)
      var lift = 0.30 + root.density * 0.70

      for (var i = 0; i < banks.length; i++) {
        var b = banks[i]
        // Every row travels with the real wind; the per-row speed is parallax
        // only, so the near deck outruns the far one instead of the layers
        // sliding against each other in a way no sky does.
        var speed = travel * b[4]
        // Seeds are placed inside the visible band first, then wrapped around
        // the oversized span, so a still deck fills the stage instead of
        // parking a third of its banks off-screen.
        var ox = (margin + b[1] * width + root.windX * speed * span) % span
        if (ox < 0) ox += span
        var oy = (vmargin + b[2] * height + root.windY * speed * vspan) % vspan
        if (oy < 0) oy += vspan
        var x = ox - margin
        var y = oy - vmargin + Math.sin(root.phase * 0.6 + i) * height * 0.014
        var radius = baseRadius * b[3] * (0.82 + root.density * 0.30)
        var alpha = (root.storm ? 0.150 : 0.115) * b[5] * lift
        drawCloud(ctx, x, y, radius, alpha)
      }

      // Falling layer. Rain is a short streak leaned by the wind; snow is a
      // slow round flake that gets pushed sideways much further for the same
      // fall distance. Both are seeded off a hash so the field is stable.
      if (root.precip > 0.02) {
        var drops = Math.round(24 + root.precip * 120)
        var fall = root.fallT / 1000
        var speedY = root.snow ? 0.055 : (0.34 + root.precip * 0.30)
        var lean = root.windX * (root.snow ? 0.55 : 0.22)
        var pc = root.cloudTint
        ctx.lineCap = "round"
        for (var d = 0; d < drops; d++) {
          // Cheap deterministic hash: no allocation, stable across repaints.
          var h1 = ((d * 9301 + 49297) % 233280) / 233280
          var h2 = ((d * 4831 + 15731) % 233280) / 233280
          var h3 = ((d * 2749 + 20789) % 233280) / 233280
          var prog = (h2 + fall * speedY * (0.7 + h3 * 0.6)) % 1
          var dx = (h1 + prog * lean) % 1
          if (dx < 0) dx += 1
          var px2 = dx * width
          var py2 = prog * height
          var a = (root.snow ? 0.30 : 0.26) * (0.45 + root.precip * 0.55) * (0.5 + h3 * 0.5)
          if (root.snow) {
            ctx.fillStyle = Qt.rgba(pc.r, pc.g, pc.b, a).toString()
            ctx.beginPath()
            ctx.arc(px2, py2, Math.max(1, width * 0.0018 * (0.7 + h3)), 0, Math.PI * 2)
            ctx.fill()
          } else {
            var len = height * (0.030 + root.precip * 0.028) * (0.7 + h3 * 0.6)
            ctx.strokeStyle = Qt.rgba(pc.r, pc.g, pc.b, a).toString()
            ctx.lineWidth = Math.max(1, width * 0.0012)
            ctx.beginPath()
            ctx.moveTo(px2, py2)
            ctx.lineTo(px2 + lean * len * 2.2, py2 + len)
            ctx.stroke()
          }
        }
      }

      // Feather all four edges. Without this the clip rectangle around the
      // stage shows up as a hard-edged grey box - the exact thing this panel
      // is trying to get away from. destination-out erases by source alpha,
      // so each gradient eats the deck back to nothing at the boundary.
      ctx.globalCompositeOperation = "destination-out"
      var fadeX = width * 0.14
      var fadeY = height * 0.16
      var edges = [
        [ctx.createLinearGradient(0, 0, fadeX, 0), 0, 0, fadeX, height],
        [ctx.createLinearGradient(width, 0, width - fadeX, 0), width - fadeX, 0, fadeX, height],
        [ctx.createLinearGradient(0, 0, 0, fadeY), 0, 0, width, fadeY],
        [ctx.createLinearGradient(0, height, 0, height - fadeY), 0, height - fadeY, width, fadeY]
      ]
      for (var e = 0; e < edges.length; e++) {
        var grad = edges[e][0]
        grad.addColorStop(0, "rgba(0,0,0,1)")
        grad.addColorStop(1, "rgba(0,0,0,0)")
        ctx.fillStyle = grad
        ctx.fillRect(edges[e][1], edges[e][2], edges[e][3], edges[e][4])
      }
      // Clear a soft hole over the hub. The deck should pass behind the
      // forecast, not sit on top of the number you came here to read.
      var holeR = Math.min(width * 0.30, height * 0.62)
      var hole = ctx.createRadialGradient(width / 2, height / 2, holeR * 0.18,
                                          width / 2, height / 2, holeR)
      hole.addColorStop(0, "rgba(0,0,0,0.92)")
      hole.addColorStop(0.55, "rgba(0,0,0,0.55)")
      hole.addColorStop(1, "rgba(0,0,0,0)")
      ctx.fillStyle = hole
      ctx.fillRect(0, 0, width, height)

      ctx.globalCompositeOperation = "source-over"
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    Connections {
      target: root
      function onDriftTChanged() { cloudCanvas.requestPaint() }
      function onPhaseChanged() { cloudCanvas.requestPaint() }
      function onDensityChanged() { cloudCanvas.requestPaint() }
      function onLiveColorChanged() { cloudCanvas.requestPaint() }
      function onCloudTintChanged() { cloudCanvas.requestPaint() }
      function onFallTChanged() { cloudCanvas.requestPaint() }
      function onPrecipChanged() { cloudCanvas.requestPaint() }
      function onWindXChanged() { cloudCanvas.requestPaint() }
      function onWindYChanged() { cloudCanvas.requestPaint() }
      function onStormChanged() { cloudCanvas.requestPaint() }
      function onActiveChanged() { cloudCanvas.requestPaint() }
    }
  }
}
