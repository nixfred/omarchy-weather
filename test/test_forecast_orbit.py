#!/usr/bin/env python3
"""Static contracts for the interactive ten-day forecast orbit."""

import json
from pathlib import Path
import unittest


PLUGIN = Path(__file__).parents[1]
PANEL = (PLUGIN / "Panel.qml").read_text(encoding="utf-8")
LOADER = (PLUGIN / "MorphingWeatherLoader.qml").read_text(encoding="utf-8")
WAVE_WIPE = (PLUGIN / "WeatherWaveWipe.qml").read_text(encoding="utf-8")
ENERGY_CORE = (PLUGIN / "WeatherEnergyCore.qml").read_text(encoding="utf-8")
README = (PLUGIN / "README.md").read_text(encoding="utf-8")
MANIFEST = json.loads((PLUGIN / "manifest.json").read_text(encoding="utf-8"))


class ForecastOrbitTests(unittest.TestCase):
    def test_direct_manipulation_and_snap_are_present(self):
        for contract in (
            "function carouselCardAt(",
            "function settleCarousel(",
            "function stepCarousel(",
            "onPositionChanged: function(mouse)",
            "onWheel: function(wheel)",
            'easing.type: Easing.OutBack',
        ):
            self.assertIn(contract, PANEL)

    def test_orbit_uses_the_full_ten_day_model(self):
        self.assertIn(
            "Model.dailyForecast(dailyForecastReport, "
            'Qt.formatDate(new Date(), "yyyy-MM-dd"), 10)',
            PANEL,
        )
        self.assertIn("model: root.daily", PANEL)

    def test_auto_spin_setting_is_wired_and_documented(self):
        defaults = MANIFEST["barWidget"]["defaults"]
        schema = {
            entry["key"]: entry for entry in MANIFEST["barWidget"]["schema"]
        }
        self.assertIs(defaults["orbitAutoSpin"], True)
        self.assertEqual(schema["orbitAutoSpin"]["type"], "boolean")
        self.assertIn('setting("orbitAutoSpin", true)', PANEL)
        self.assertIn("orbitAutoSpin", README)

    def test_reactive_effects_remain_wired_to_weather_and_motion(self):
        for contract in (
            "function weatherAccentForCode(",
            "property real weatherAmbientPhase",
            "property real weatherWavePhase",
            "property real carouselLean",
            "function isStormCode(",
            "id: liquidCanvas",
            "angle: root.carouselLean",
            "root.carouselStorm",
        ):
            self.assertIn(contract, PANEL)

    def test_loading_state_uses_the_morphing_canvas(self):
        self.assertIn("MorphingWeatherLoader {", PANEL)
        self.assertIn("Canvas {", LOADER)
        self.assertIn("quadraticCurveTo", LOADER)
        self.assertIn("loops: Animation.Infinite", LOADER)

    def test_refresh_and_location_changes_use_the_wave_wipe(self):
        for contract in (
            "function beginWeatherTransition(",
            "function completeWeatherTransition(",
            "id: weatherWipeCover",
            "id: weatherWipeReveal",
            'beginWeatherTransition("location")',
            "WeatherWaveWipe {",
        ):
            self.assertIn(contract, PANEL)
        self.assertIn("ctx.bezierCurveTo(", WAVE_WIPE)
        self.assertIn("property real direction", WAVE_WIPE)
        self.assertIn("root.weatherWipeDirection = dx > 0 ? 1 : -1", PANEL)
        self.assertIn("layered, condition-colored", README)

    def test_selected_day_has_a_phase_shifted_energy_core(self):
        for contract in (
            "property real weatherCorePhase",
            "NumberAnimation on weatherCorePhase",
            "WeatherEnergyCore {",
            "phase: root.weatherCorePhase",
            "storm: root.carouselStorm",
        ):
            self.assertIn(contract, PANEL)
        self.assertIn("ctx.createRadialGradient(", ENERGY_CORE)
        self.assertIn("var ringScales = [", ENERGY_CORE)
        self.assertIn("Counter-rotating partial arcs", ENERGY_CORE)


if __name__ == "__main__":
    unittest.main()
