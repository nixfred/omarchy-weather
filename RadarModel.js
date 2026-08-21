// Saved radar websites, location parsing, and alert helpers.
//
// There is no in-panel radar map. Open radar launches a user-saved https
// site. Alert sampling still uses a few nearby coordinates so a town is not
// treated as a single grid cell.

.pragma library

var GLYPH = String.fromCodePoint(0xF0437)   // nf-md-radar
var MAX_ALERT_JSON_BYTES = 1048576
var ALERT_INTERVAL_SEC = 600
var FRAME_INTERVAL_SEC = ALERT_INTERVAL_SEC

function curlGet(url, maxTimeSec, maxBytes) {
  var cap = parseInt(maxBytes, 10)
  if (!isFinite(cap) || cap < 1) cap = MAX_ALERT_JSON_BYTES
  var secs = parseInt(maxTimeSec, 10)
  if (!isFinite(secs) || secs < 1) secs = 10
  return ["curl", "-fsS", "--max-time", String(secs), "--max-filesize", String(cap), url]
}

function rejectOversized(raw, maxBytes) {
  var cap = parseInt(maxBytes, 10)
  if (!isFinite(cap) || cap < 1) cap = MAX_ALERT_JSON_BYTES
  return String(raw || "").length > cap
}

function stripUrlQueryAndFragment(url) {
  var text = String(url || "")
  var end = text.length
  var query = text.indexOf("?")
  var hash = text.indexOf("#")
  if (query !== -1 && query < end) end = query
  if (hash !== -1 && hash < end) end = hash
  return text.slice(0, end)
}

function hostnameFromHttpsUrl(url) {
  var text = stripUrlQueryAndFragment(url)
  if (text.indexOf("https://") !== 0) return ""
  var rest = text.slice(8)
  var slash = rest.indexOf("/")
  var hostname = (slash === -1 ? rest : rest.slice(0, slash)).toLowerCase()
  if (hostname === "" || hostname.indexOf("@") !== -1 || hostname.indexOf(":") !== -1) return ""
  return hostname
}

var BROWSER_RADAR_HOST = "https://www.rainviewer.com/map.html"
var RADAR_SITES = ["RainViewer", "NOAA", "Windy", "Weather Underground", "Custom"]

function browserRadarUrl(latitude, longitude) {
  var lat = parseFloat(latitude)
  var lon = parseFloat(longitude)
  if (!isFinite(lat) || !isFinite(lon)) return BROWSER_RADAR_HOST
  if (Math.abs(lat) > 90 || Math.abs(lon) > 180) return BROWSER_RADAR_HOST
  return BROWSER_RADAR_HOST + "?loc=" + lat.toFixed(4) + "," + lon.toFixed(4) + ",7"
}

function noaaRadarUrl(latitude, longitude) {
  var lat = parseFloat(latitude)
  var lon = parseFloat(longitude)
  if (!isFinite(lat) || !isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180)
    return "https://radar.weather.gov/"
  return "https://radar.weather.gov/?lat=" + lat.toFixed(4) + "&lon=" + lon.toFixed(4)
}

function windyRadarUrl(latitude, longitude) {
  var lat = parseFloat(latitude)
  var lon = parseFloat(longitude)
  if (!isFinite(lat) || !isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180)
    return "https://www.windy.com/-Radar-radar"
  return "https://www.windy.com/" + lat.toFixed(4) + "/" + lon.toFixed(4)
    + "?radar," + lat.toFixed(4) + "," + lon.toFixed(4) + ",8"
}

function wundergroundRadarUrl(latitude, longitude) {
  var lat = parseFloat(latitude)
  var lon = parseFloat(longitude)
  if (!isFinite(lat) || !isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180)
    return "https://www.wunderground.com/wundermap"
  return "https://www.wunderground.com/wundermap?lat=" + lat.toFixed(4)
    + "&lon=" + lon.toFixed(4) + "&zoom=8&radar=1"
}

function sanitizeCustomRadarUrl(template, latitude, longitude) {
  var url = String(template || "").trim()
  var lat = parseFloat(latitude)
  var lon = parseFloat(longitude)
  if (isFinite(lat) && isFinite(lon)) {
    url = url.split("{lat}").join(lat.toFixed(4))
    url = url.split("{lon}").join(lon.toFixed(4))
  }
  if (url.indexOf("https://") !== 0) return ""
  if (url.length > 2048 || /\s/.test(url) || url.indexOf("\\") !== -1) return ""
  var lower = url.toLowerCase()
  if (lower.indexOf("javascript:") !== -1 || lower.indexOf("data:") !== -1 || lower.indexOf("file:") !== -1) return ""
  if (hostnameFromHttpsUrl(url) === "") return ""
  return url
}

function resolveRadarUrl(site, customTemplate, latitude, longitude) {
  var name = String(site || "RainViewer")
  if (name === "NOAA") return noaaRadarUrl(latitude, longitude)
  if (name === "Windy") return windyRadarUrl(latitude, longitude)
  if (name === "Weather Underground") return wundergroundRadarUrl(latitude, longitude)
  if (name === "Custom") return sanitizeCustomRadarUrl(customTemplate, latitude, longitude)
  return browserRadarUrl(latitude, longitude)
}

function parseLocationFile(raw) {
  var unset = { name: "", latitude: null, longitude: null, valid: false }
  var text = String(raw || "").trim()
  if (text === "") return unset

  var data
  try {
    data = JSON.parse(text)
  } catch (e) {
    return unset
  }
  if (!data) return unset

  var latitude = parseFloat(data.latitude)
  var longitude = parseFloat(data.longitude)
  var valid = isFinite(latitude) && isFinite(longitude)
    && latitude >= -90 && latitude <= 90
    && longitude >= -180 && longitude <= 180

  return {
    name: String(data.name || ""),
    latitude: valid ? latitude : null,
    longitude: valid ? longitude : null,
    valid: valid
  }
}

var SAMPLE_RADIUS_KM = 5

function samplePoints(lat, lon, km) {
  lat = parseFloat(lat)
  lon = parseFloat(lon)
  if (!isFinite(lat) || !isFinite(lon)) return []

  var radius = km || SAMPLE_RADIUS_KM
  var dLat = radius / 111.32
  var cos = Math.cos(lat * Math.PI / 180)
  var dLon = Math.abs(cos) < 0.01 ? 0 : radius / (111.32 * cos)

  return [
    { latitude: lat, longitude: lon },
    { latitude: clampLat(lat + dLat), longitude: lon },
    { latitude: clampLat(lat - dLat), longitude: lon },
    { latitude: lat, longitude: wrapLon(lon + dLon) },
    { latitude: lat, longitude: wrapLon(lon - dLon) }
  ]
}

function clampLat(lat) {
  return Math.max(-90, Math.min(90, lat))
}

function wrapLon(lon) {
  return ((lon + 180) % 360 + 360) % 360 - 180
}
