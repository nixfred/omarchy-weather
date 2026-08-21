import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "TileMath.js" as TileMath
import "RadarModel.js" as RadarModel

Item {
  id: root
  property var bar: null
  property var radar: null
  property var settings: ({})
  property bool active: false
  property string moduleName: "io.github.calebhat.weather"
  property real peekLatitude: Number.NaN
  property real peekLongitude: Number.NaN
  property string peekName: ""
  readonly property bool peeking: isFinite(peekLatitude) && isFinite(peekLongitude)

  readonly property bool alertsEnabled: setting("alertsEnabled", false) === true
  readonly property int alertRadiusKm: Math.max(25, Math.min(250, Number(setting("alertRadiusKm", 100)) || 100))
  readonly property int alertLeadMinutes: radar ? radar.leadMinutes : Math.round(alertRadiusKm / 50 * 60)
  readonly property bool smoothTiles: setting("smoothTiles", true) === true
  readonly property bool showSnow: setting("showSnow", true) === true
  readonly property int colorSchemeId: {
    var name = String(setting("colorScheme", "TITAN"))
    for (var i = 0; i < RadarModel.COLOR_SCHEMES.length; i++) {
      if (RadarModel.COLOR_SCHEMES[i].name === name) return RadarModel.COLOR_SCHEMES[i].id
    }
    return 2
  }

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function persistSetting(key, value) {
    if (!root.bar || !root.bar.shell || typeof root.bar.shell.updateEntryInline !== "function") return
    var entry = { id: root.moduleName }
    for (var existing in settings) if (existing !== "id") entry[existing] = settings[existing]
    entry[key] = value
    root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function humanizeLead(minutes) {
    if (minutes < 60) return minutes + " min"
    var hours = Math.floor(minutes / 60)
    var rest = minutes % 60
    if (rest === 0) return hours + " h"
    return hours + " h " + rest + " min"
  }

  readonly property bool hasLocation: peeking || (radar ? radar.hasLocation === true : false)
  property real homeLatitude: 0
  property real homeLongitude: 0
  readonly property real focusLatitude: peeking ? peekLatitude : homeLatitude
  readonly property real focusLongitude: peeking ? peekLongitude : homeLongitude

  function updateHome() {
    if (!radar || !radar.location) return
    var la = parseFloat(radar.location.latitude)
    var lo = parseFloat(radar.location.longitude)
    if (!isFinite(la) || !isFinite(lo)) return
    homeLatitude = la
    homeLongitude = lo
    if (!panned) recenter()
  }

  Connections {
    target: root.radar
    function onLocationChanged() { root.updateHome() }
  }

  onRadarChanged: {
    updateHome()
    syncManifest()
  }
  readonly property string locationName: peeking ? peekName : (radar ? radar.locationName : "")

  property real viewLatitude: 0
  property real viewLongitude: 0
  property int zoom: Math.max(RadarModel.MIN_RADAR_ZOOM,
    Math.min(RadarModel.MAX_MAP_ZOOM, Number(setting("defaultZoom", 7)) || 7))
  readonly property int radarSourceZoom: Math.min(zoom, RadarModel.MAX_RADAR_ZOOM)
  property bool panned: false

  function recenter() {
    if (peeking) {
      viewLatitude = peekLatitude
      viewLongitude = peekLongitude
      return
    }
    if (!hasLocation) return
    viewLatitude = homeLatitude
    viewLongitude = homeLongitude
  }

  onHasLocationChanged: updateHome()
  onPeekLatitudeChanged: { panned = false; recenter() }
  onPeekLongitudeChanged: { panned = false; recenter() }

  readonly property var frames: radar ? radar.frames : []
  property int frameIndex: 0
  property bool playing: false
  readonly property var currentFrame: {
    if (!frames || frames.length === 0) return null
    var index = Math.max(0, Math.min(frames.length - 1, frameIndex))
    return frames[index]
  }
  readonly property string frameLabel: currentFrame ? RadarModel.formatFrameTime(currentFrame.time) : "--:--"
  readonly property bool isLatestFrame: frames.length > 0 && frameIndex >= frames.length - 1

  onFramesChanged: {
    if (frames.length === 0) return
    if (frameIndex >= frames.length - 1 || frameIndex === 0) frameIndex = frames.length - 1
    if (frameA < 0) { frameA = frameIndex; frontIsA = true }
  }

  property int frameA: -1
  property int frameB: -1
  property bool frontIsA: true
  onFrameIndexChanged: showFrame(frameIndex)

  // Load the new frame on the hidden layer and promote it only once its
  // tiles are ready. Swapping immediately showed an empty overlay (the
  // precipitation) against the dark basemap until the next PNG arrived.
  function showFrame(index) {
    if (index < 0 || frames.length === 0) return
    var frontIndex = frontIsA ? frameA : frameB
    if (index === frontIndex) return
    if (frontIsA) frameB = index
    else frameA = index
    Qt.callLater(promoteIfReady)
  }

  function promoteIfReady() {
    var back = frontIsA ? radarB : radarA
    var backIndex = frontIsA ? frameB : frameA
    if (!back || backIndex !== frameIndex) return
    if (!back.ready) return
    frontIsA = !frontIsA
  }

  function radarTileUrlForFrame(index, z, x, y) {
    if (!root.radar || !root.radar.tileHost) return ""
    if (index < 0 || index >= root.frames.length) return ""
    return RadarModel.tileUrl(root.radar.tileHost, root.frames[index].path, 256,
      z, x, y, root.colorSchemeId, root.smoothTiles, root.showSnow)
  }

  Timer {
    id: playbackTimer
    interval: root.isLatestFrame ? 1500 : 550
    repeat: true
    running: root.playing && root.active && root.frames.length > 1
    onTriggered: {
      if (root.frameIndex >= root.frames.length - 1) root.frameIndex = 0
      else root.frameIndex++
    }
  }

  property bool manifestHeld: false

  function syncManifest() {
    var want = root.active && root.radar
    if (want && !manifestHeld) {
      root.radar.acquireManifest()
      manifestHeld = true
      if (!panned && hasLocation) recenter()
      Qt.callLater(function() { coverageProbe.probe() })
    } else if (!want && manifestHeld && root.radar) {
      root.playing = false
      root.radar.releaseManifest()
      manifestHeld = false
    }
  }

  onActiveChanged: syncManifest()
  Component.onDestruction: {
    if (manifestHeld && root.radar && root.radar.releaseManifest) root.radar.releaseManifest()
  }

  function stepFrame(delta) {
    root.playing = false
    root.frameIndex = Math.max(0, Math.min(root.frames.length - 1, root.frameIndex + delta))
  }

  function zoomBy(delta) {
    root.zoom = Math.max(RadarModel.MIN_RADAR_ZOOM, Math.min(RadarModel.MAX_MAP_ZOOM, root.zoom + delta))
  }

  function openInBrowser() {
    var url = RadarModel.browserRadarUrl(root.focusLatitude, root.focusLongitude)
    if (url.indexOf("https://www.rainviewer.com/map.html") !== 0) return
    Quickshell.execDetached(["omarchy-launch-browser", url])
  }

  readonly property bool darkTheme: {
    var background = Color.background
    return (0.2126 * background.r + 0.7152 * background.g + 0.0722 * background.b) < 0.5
  }
  readonly property string basemapStyle: darkTheme ? "dark_all" : "light_all"
  function basemapTileUrl(z, x, y) {
    return "https://basemaps.cartocdn.com/" + basemapStyle + "/" + z + "/" + x + "/" + y + ".png"
  }
  function radarTileUrlA(z, x, y) { return root.radarTileUrlForFrame(root.frameA, z, x, y) }
  function radarTileUrlB(z, x, y) { return root.radarTileUrlForFrame(root.frameB, z, x, y) }

  readonly property string coverageProbeUrl: {
    if (peeking) return ""
    if (!radar || !radar.tileHost || !hasLocation) return ""
    if (radar.coverageChecked) return ""
    return RadarModel.coverageTileUrl(radar.tileHost, 256, RadarModel.MAX_RADAR_ZOOM,
      homeLatitude, homeLongitude)
  }
  readonly property bool coverageMissing: peeking ? false : (radar ? (radar.coverageChecked && !radar.hasCoverage) : false)

  implicitHeight: content.implicitHeight
  implicitWidth: content.implicitWidth

  Column {
    id: content
    width: parent.width
    spacing: Style.space(10)

    Item {
      id: mapArea
      width: parent.width
      height: Style.space(320)

      Rectangle {
        anchors.fill: parent
        color: root.darkTheme ? "#101014" : "#e8e8ec"
        radius: Style.cornerRadius
        clip: true

        TileLayer {
          anchors.fill: parent
          centerLatitude: root.viewLatitude
          centerLongitude: root.viewLongitude
          zoom: root.zoom
          tileUrlFor: root.basemapTileUrl
        }

        TileLayer {
          id: radarA
          anchors.fill: parent
          centerLatitude: root.viewLatitude
          centerLongitude: root.viewLongitude
          zoom: root.zoom
          sourceZoom: root.radarSourceZoom
          tileUrlFor: root.radarTileUrlA
          revision: root.frameA + (root.colorSchemeId * 1000)
          smooth: root.smoothTiles
          opacity: root.frontIsA ? 1 : 0
          onReadyChanged: if (ready) root.promoteIfReady()
          Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.InOutQuad } }
        }

        TileLayer {
          id: radarB
          anchors.fill: parent
          centerLatitude: root.viewLatitude
          centerLongitude: root.viewLongitude
          zoom: root.zoom
          sourceZoom: root.radarSourceZoom
          tileUrlFor: root.radarTileUrlB
          revision: root.frameB + (root.colorSchemeId * 1000)
          smooth: root.smoothTiles
          opacity: root.frontIsA ? 0 : 1
          onReadyChanged: if (ready) root.promoteIfReady()
          Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.InOutQuad } }
        }

        Item {
          anchors.fill: parent
          visible: root.hasLocation
          readonly property var home: TileMath.projectToViewport(
            root.homeLatitude, root.homeLongitude,
            root.viewLatitude, root.viewLongitude,
            root.zoom, parent.width, parent.height)
          readonly property real ringRadius: TileMath.kmToPixels(
            root.alertRadiusKm, root.homeLatitude, root.zoom)

          Repeater {
            model: [0.5, 1.0]
            Rectangle {
              required property real modelData
              readonly property real r: parent.ringRadius * modelData
              x: parent.home.x - r
              y: parent.home.y - r
              width: r * 2
              height: r * 2
              radius: r
              color: "transparent"
              border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b,
                modelData === 1.0 ? 0.55 : 0.3)
              border.width: 1
              visible: root.alertsEnabled && r > 6 && r < parent.width * 2
            }
          }

          Rectangle {
            readonly property real dot: Style.space(7)
            x: parent.home.x - dot / 2
            y: parent.home.y - dot / 2
            width: dot
            height: dot
            radius: dot / 2
            color: Color.accent
            border.color: root.darkTheme ? "#000000" : "#ffffff"
            border.width: 1
          }
        }

        MouseArea {
          id: mapMouse
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton
          cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
          property real lastX: 0
          property real lastY: 0
          onPressed: function(mouse) { lastX = mouse.x; lastY = mouse.y }
          onPositionChanged: function(mouse) {
            if (!pressed) return
            var dx = mouse.x - lastX
            var dy = mouse.y - lastY
            if (dx === 0 && dy === 0) return
            lastX = mouse.x
            lastY = mouse.y
            var moved = TileMath.unprojectFromViewport(
              width / 2 - dx, height / 2 - dy,
              root.viewLatitude, root.viewLongitude,
              root.zoom, width, height)
            root.viewLatitude = moved.latitude
            root.viewLongitude = moved.longitude
            root.panned = true
          }
          onWheel: function(wheel) {
            var direction = wheel.angleDelta.y > 0 ? 1 : -1
            root.zoomBy(direction)
            wheel.accepted = true
          }
        }

        Text {
          textFormat: Text.PlainText
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.margins: Style.space(6)
          text: "RainViewer · CARTO · OpenStreetMap"
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.caption * 0.8
          opacity: 0.4
        }

        Canvas {
          id: coverageProbe
          width: 256
          height: 256
          opacity: 0
          z: -1
          property string probeUrl: root.coverageProbeUrl
          function probe() {
            if (probeUrl === "") return
            if (isImageLoaded(probeUrl)) requestPaint()
            else loadImage(probeUrl)
          }
          onProbeUrlChanged: probe()
          onImageLoaded: requestPaint()
          onPaint: {
            if (probeUrl === "" || !isImageLoaded(probeUrl)) return
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.drawImage(probeUrl, 0, 0, width, height)
            var pixels = ctx.getImageData(0, 0, width, height).data
            var covered = RadarModel.hasCoverageAtCenter(pixels, width)
            if (root.radar && root.radar.reportCoverage) root.radar.reportCoverage(covered)
          }
        }

        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          visible: !root.hasLocation || (root.frames.length === 0) || (!radarA.ready && !radarB.ready)
          text: root.hasLocation ? "Loading radar…" : "Set a location to centre radar"
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          opacity: 0.6
        }
      }
    }

    Item {
      width: parent.width
      height: Style.spacing.controlHeight
      visible: root.frames.length > 1

      Button {
        id: playButton
        anchors.left: parent.left
        anchors.leftMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        text: root.playing ? "󰏤" : "󰐊"
        fontFamily: Style.font.family
        foreground: root.bar ? root.bar.foreground : Color.foreground
        tooltipText: root.playing ? "Pause" : "Play the last two hours"
        onClicked: root.playing = !root.playing
      }

      PanelSlider {
        anchors.left: playButton.right
        anchors.right: frameTime.left
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        bar: root.bar
        minimum: 0
        maximum: Math.max(1, root.frames.length - 1)
        integer: true
        step: 1
        tickCount: root.frames.length
        value: root.frameIndex
        onMoved: function(value) {
          root.playing = false
          root.frameIndex = Math.round(value)
        }
      }

      Text {
        textFormat: Text.PlainText
        id: frameTime
        anchors.right: parent.right
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(44)
        horizontalAlignment: Text.AlignRight
        text: root.frameLabel
        color: root.bar ? root.bar.foreground : Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        opacity: root.isLatestFrame ? 0.9 : 0.6
      }
    }

    Item {
      width: parent.width
      height: Style.spacing.controlHeight

      Text {
        textFormat: Text.PlainText
        anchors.left: parent.left
        anchors.leftMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        text: root.coverageMissing ? (root.locationName + " · no radar coverage") : (root.locationName || "Radar")
        color: root.coverageMissing ? Color.urgent : (root.bar ? root.bar.foreground : Color.foreground)
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        opacity: root.locationName !== "" ? 1 : 0.6
      }

      Button {
        anchors.right: parent.right
        anchors.rightMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        text: "Open radar"
        fontFamily: Style.font.family
        foreground: root.bar ? root.bar.foreground : Color.foreground
        tooltipText: "Open today's radar in your default browser"
        onClicked: root.openInBrowser()
      }
    }

    Item {
      width: parent.width
      height: Style.spacing.controlHeight

      Column {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Text {
          textFormat: Text.PlainText
          text: "Storm alerts"
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
        Text {
          textFormat: Text.PlainText
          text: {
            if (!root.alertsEnabled) return "off"
            if (!root.hasLocation) return "no location set"
            if (root.radar && root.radar.checking) return "checking…"
            if (root.radar && root.radar.lastCheckTime > 0) {
              if (root.radar.outlookLevel === 0) return "nothing expected"
              var outlook = root.radar.outlookLabel.toLowerCase() + " expected"
              return root.radar.outlookAtClock !== ""
                ? outlook + " around " + root.radar.outlookAtClock
                : outlook
            }
            return "starting…"
          }
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          opacity: 0.55
        }
      }

      ToggleSwitch {
        anchors.right: parent.right
        anchors.rightMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        checked: root.alertsEnabled
        busy: root.alertsEnabled && root.radar ? root.radar.checking : false
        foreground: root.bar ? root.bar.foreground : Color.foreground
        onToggled: {
          var next = !root.alertsEnabled
          root.persistSetting("alertsEnabled", next)
          if (next && root.radar && root.radar.checkNow) Qt.callLater(root.radar.checkNow)
        }
      }
    }
  }
}
