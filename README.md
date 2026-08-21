# Weather

A weather widget for the [Omarchy](https://omarchy.org) bar. It **replaces**
the built-in `omarchy.weather` pill with a panel that has:

- current conditions
- remaining hours for **today**
- a **five-day** forecast
- a live **radar** map (RainViewer)
- **Open radar**, which launches today's radar in your default browser

Forecast data comes from [Open-Meteo](https://open-meteo.com) and
[wttr.in](https://wttr.in). Radar tiles come from
[RainViewer](https://www.rainviewer.com). No API key.

This plugin combines MIT-licensed work from
[Weathering](https://github.com/howdyitskyle/weathering-omarchy-plugin) and
[Weather Radar](https://github.com/eduardodallecort/omarchy-weather-radar).
See [NOTICE.md](NOTICE.md).

## Install

```sh
omarchy plugin add https://github.com/calebhat/omarchy-weather.git --enable
```

Enabling it takes the built-in weather slot (`clonedFrom: omarchy.weather`).
If the stock pill is still visible:

```sh
omarchy plugin disable omarchy.weather
omarchy bar move io.github.calebhat.weather --section center
```

Then restart the shell so the radar service mounts:

```sh
omarchy restart shell
```

## Use

Click the pill to open or close the panel. **Forecast** shows today and the
five-day outlook. **Radar** shows the last two hours of precipitation over
your location.

**Open radar** (on both tabs) opens RainViewer in your default browser,
centred on the same coordinates.

Middle-click the pill to refresh the forecast. Right-click sends a
notification of current conditions. Escape closes the panel.

Location is shared with Omarchy's weather file
(`~/.local/state/omarchy/settings/weather.json`). Click the location label
to change home; an empty commit returns to IP auto-detect. The search icon
peeks at another city without saving it — forecast and radar follow the
peek, the bar pill stays on home, and **Back to …** (or closing the panel)
returns. Storm alerts always use the saved home.

Optional storm alerts default **off**. Turn them on from the radar tab or
the widget settings.

## Remove

```sh
omarchy plugin remove io.github.calebhat.weather
```

Removal restores the built-in weather widget. It does not delete
`weather.json`.

## Data

- Open-Meteo — current, hourly, daily, air quality, geocoding
- wttr.in — IP auto-detect when no location is stored
- RainViewer — radar frames (fetched only while the radar tab is open,
  except optional alerts)
- CARTO / OpenStreetMap — basemap tiles

## Security

Plugins run unsandboxed inside `omarchy-shell`. This one talks to the HTTPS
endpoints above, writes location through `omarchy-weather-location`, and
opens URLs only as `https://www.rainviewer.com/map.html…` via
`omarchy-launch-browser`. Process invocations use argv arrays, not a shell
string.

## License

MIT — see [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
