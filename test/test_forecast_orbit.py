#!/usr/bin/env python3
"""Static contracts for the interactive ten-day forecast orbit."""

import json
from pathlib import Path
import unittest


PLUGIN = Path(__file__).parents[1]
PANEL = (PLUGIN / "Panel.qml").read_text(encoding="utf-8")
LOADER = (PLUGIN / "MorphingWeatherLoader.qml").read_text(encoding="utf-8")
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


if __name__ == "__main__":
    unittest.main()
