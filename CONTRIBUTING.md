# Contributing

Source of truth: this repository, installed as a normal Omarchy plugin.

```bash
omarchy plugin add https://github.com/calebhat/omarchy-weather.git --enable
omarchy plugin validate ~/.config/omarchy/plugins/io.github.calebhat.weather
```

Edit that checkout. Do not keep a second copy inside private dotfiles.

Forecast UI follows Weathering; radar follows omarchy-weather-radar. Keep
location in `~/.local/state/omarchy/settings/weather.json` via
`omarchy-weather-location`. Do not add a second location store.

Browser radar must stay an argv call to `omarchy-launch-browser` with an
`https://www.rainviewer.com/map.html` URL built from numeric coordinates.
Do not restore `bar.run` with `$(…)` for notifications.

Commit as `calebhat <97716470+calebhat@users.noreply.github.com>`.

Marketplace listing: open or **edit** the existing `[Plugin]: Weather`
issue on HANCORE-linux/omarchy-plugin-marketplace. Do not open a duplicate.
