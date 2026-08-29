#!/usr/bin/env python3
"""Static lifecycle regressions for delayed QML callbacks."""
from pathlib import Path
import re
import unittest


PANEL = (Path(__file__).parents[1] / "Panel.qml").read_text(encoding="utf-8")


class PanelLifecycleTests(unittest.TestCase):
    def test_delayed_refreshes_are_guarded_against_destroyed_panel(self):
        self.assertNotRegex(PANEL, r"Qt\.callLater\((?:root\.)?refresh\)")
        self.assertIn("function scheduleRefresh()", PANEL)
        scheduler = re.search(
            r"function scheduleRefresh\(\) \{(?P<body>.*?)\n  \}", PANEL, re.DOTALL
        )
        self.assertIsNotNone(scheduler)
        assert scheduler is not None
        body = scheduler.group("body")
        self.assertIn("root.refreshDailyForecast", body)
        self.assertIn("root.refresh()", body)
        self.assertGreaterEqual(PANEL.count("scheduleRefresh()"), 4)


if __name__ == "__main__":
    unittest.main()
