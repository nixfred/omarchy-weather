# AGENTS.md

Omarchy shell plugin (`service` + `bar-widget`). Replaces `omarchy.weather`
via `omarchy.clonedFrom`.

## Layout

- `manifest.json` — contract, settings schema, `clonedFrom`
- `BarWidget.qml` — bar pill; forwards panel contract; injects the service
- `Panel.qml` — forecast tab + hosts `RadarPane.qml`
- `RadarPane.qml` — RainViewer map, timeline, Open radar, alerts toggle
- `Service.qml` — RainViewer manifest + optional storm alerts (one per session)
- `Model.js` — forecast parsing (Open-Meteo / wttr)
- `RadarModel.js`, `TileMath.js`, `TileLayer.qml` — radar map

## Data

Open-Meteo, wttr.in, RainViewer, CARTO. Location file owned by
`omarchy-weather-location`. Radar frames fetch only while the radar tab is
open (`acquireManifest` / `releaseManifest`).

## Dev

```
omarchy plugin validate ~/.config/omarchy/plugins/io.github.calebhat.weather
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml RadarPane.qml Service.qml TileLayer.qml
omarchy restart shell
```

Hot reload of QML is unreliable after atomic writes; restart the shell.
