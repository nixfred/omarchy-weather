# Weather

A single Omarchy bar pill that **replaces** the built-in `omarchy.weather`
widget. Click it for today's hourly forecast, a five-day outlook, and a live
radar map. **Open radar** launches today's radar in your default browser.

No API key. Location is the same file Omarchy already uses.

<p align="center"><img src="preview.png" alt="Weather panel" width="520"></p>

## Why this exists

Omarchy's stock weather pill shows current conditions and a short outlook.
[Weathering](https://github.com/howdyitskyle/weathering-omarchy-plugin) is a
richer forecast panel. [Weather Radar](https://github.com/eduardodallecort/omarchy-weather-radar)
is a separate radar pill.

This plugin is those two ideas in **one slot**: the stock header goes away,
forecast and radar share a panel, and you can peek at another city without
changing home. If you already run Weathering *and* Weather Radar side by
side, you do not need this. If you want one widget that stands in for
`omarchy.weather`, this is that.

It is MIT-licensed work adapted from Weathering and Weather Radar plus the
stock weather contract. See [NOTICE.md](NOTICE.md).

## Features

### Bar pill

Replaces the built-in weather icon in the centre of the bar (`clonedFrom:
omarchy.weather`). The pill shows the current condition glyph for your
**saved home** location, even while the panel is peeking at another city.

| Input | Action |
|-------|--------|
| Left-click | Open or close the panel |
| Middle-click | Refresh the forecast |
| Right-click | Notification with current conditions (`omarchy-weather-status`) |
| Escape (panel open) | Close |

### Forecast tab

Current temperature and condition, feels-like, wind, and precipitation
chance. Below that:

- **Today** — remaining hours of the current local day (not a fixed six-cell
  strip). Scroll sideways if the day is long. The first cell is **NOW**.
- **Metrics** — wind (speed and direction), humidity, pressure, UV, air
  quality (US AQI, PM2.5 / PM10), sunrise and sunset. Each block can be
  hidden in settings.
- **Five-day** — today plus the next four days, high / low and condition.

Units follow `auto` (locale and country), `metric`, or `imperial`.

### Radar tab

Live precipitation from [RainViewer](https://www.rainviewer.com) over a
CARTO / OpenStreetMap basemap, centred on the city you are viewing (home or
peek).

- Drag to pan, wheel to zoom, Home to recetre
- Play / scrub the last two hours of frames
- The current overlay stays on screen until the next timestamp's tiles have
  loaded, then the two crossfade (no empty black flash)
- Radar tiles are fetched only while this tab is open

This is **precipitation**, not cloud. An overcast dry sky is an empty map.

### Open radar

On both tabs, **Open radar** opens RainViewer in your default browser
(`omarchy-launch-browser`), centred on the same coordinates. The URL is
always `https://www.rainviewer.com/map.html…`.

### Home location

Shared with stock Omarchy weather:
`~/.local/state/omarchy/settings/weather.json`, via
`omarchy-weather-location`. Click the **pin / city name** to search and
**save** a new home. An empty commit returns to IP auto-detect. Changing
home here also moves any other widget that reads that file.

### Peek

The **search** icon next to the city name looks up another place **without
saving it**.

- Pick a geocoded suggestion (a typed name alone is not enough)
- Forecast, radar, and **Open radar** follow the peeked city
- The bar pill stays on home
- Storm alerts stay on home
- **Back to \<home\>** returns; closing the panel does the same

Use peek for “what’s the weather in Madison.” Use the pin to actually move
home.

### Storm alerts (off by default)

Optional. When on, a background check looks at the forecast around **home**
(not a peek) and notifies if rain or a storm is expected inside the alert
radius. Toggle from the radar tab or widget settings. Not a life-safety
tool — use your national weather service for decisions that matter.

## Install

```sh
omarchy plugin add https://github.com/calebhat/omarchy-weather.git --enable
omarchy restart shell
```

`--enable` takes the built-in weather slot. If the stock pill is still
visible:

```sh
omarchy plugin disable omarchy.weather
omarchy bar move io.github.calebhat.weather --section center
omarchy restart shell
```

Do not enable this together with Weathering or Weather Radar in the same
bar slot unless you want two weather pills. Disable those if you are
switching.

## Configure

Settings live on the widget’s entry in `~/.config/omarchy/shell.json` (or
the bar settings form). `shell.json` hot-reloads on save.

| Key | Default | Meaning |
|-----|---------|---------|
| `unit` | `auto` | `auto` / `metric` / `imperial` |
| `refreshMinutes` | `15` | Forecast refresh, 5–120 |
| `showHourly` | `true` | Remaining hours for today |
| `showForecast` | `true` | Five-day strip |
| `showMetrics` | `true` | Wind / humidity / pressure / UV grid |
| `showSun` | `true` | Sunrise / sunset cell |
| `showAirQuality` | `true` | US AQI cell |
| `showFeelsLike` | `true` | Feels-like in the header |
| `alertsEnabled` | `false` | Storm alerts for home |
| `alertRadiusKm` | `100` | How far ahead to watch |
| `alertMinIntensity` | `Heavy` | `Light` / `Moderate` / `Heavy` / `Severe` |
| `colorScheme` | `TITAN` | RainViewer palette |
| `defaultZoom` | `7` | Map open zoom (radar data stops at 7; the basemap can go further) |
| `smoothTiles` | `true` | Blend radar pixels |
| `showSnow` | `true` | Colour snow separately from rain |

## Remove

```sh
omarchy plugin remove io.github.calebhat.weather
```

The built-in weather widget comes back. `weather.json` is left alone.

## Data

| Source | Used for |
|--------|----------|
| Open-Meteo | Current, hourly, daily, air quality, city search |
| wttr.in | IP auto-detect when no home coordinates are stored |
| RainViewer | Radar frames (while the radar tab is open; alerts use the forecast) |
| CARTO / OpenStreetMap | Basemap |

## Security

Plugins run unsandboxed inside `omarchy-shell`. This one:

- Fetches the HTTPS endpoints above
- Writes home location only through `omarchy-weather-location` (argv, no
  shell). Peek never writes that file
- Opens the browser only with `omarchy-launch-browser` and an
  `https://www.rainviewer.com/map.html` URL built from numeric coordinates
- Invokes every process as an argv array (`curl`, `omarchy-weather-status`,
  `omarchy-notification-send`, `omarchy-weather-location`). No `bash -c`,
  no `$(…)`, no pipe-to-shell
- Accepts RainViewer tile hosts only over `https://*.rainviewer.com`

Right-click on the pill runs `omarchy-weather-status`, then
`omarchy-notification-send` with that output as an argument.

## License

MIT — [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
