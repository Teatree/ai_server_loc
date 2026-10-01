# Usage Metrics

The page is a hardware usage timeline: the chart is the primary surface, with the
date range, resource selection, resolution, and live state directly above it.
Keep the existing dashboard's dark instrument-panel identity. Palette: background
#090d0c, panel #111716, text #f2f5f4, muted #8d9997, cyan #54d8e7, green #64edab.
Use system sans-serif for headings and controls, Consolas/system monospace for
numbers. No external fonts, chart libraries, or network assets.

Portrait layout: title/back link; wrapping range presets; two-column controls;
full-width chart per selected device; tap inspection; wrapping app legend;
three summary indicators; electricity chart; application totals; methodology.
Desktop adds horizontal control space, but never combines CPU, RAM, and GPU
percentages into a misleading shared total. Small multiples share the time range.

Controls: 8h through 10y presets, custom start/end, minute/hour/day resolution,
explicit earlier/later and zoom buttons, touch inspection, live follow,
bar/line toggle, app visibility, reset, fullscreen, CSV export, and UTC/local time.
Cost settings live in the browser and never modify the server's history.

Collection: independent unprivileged Ubuntu user service, every 15 seconds.
Existing AI services, dashboard backend, and original remote connector stay running.
Keep compressed minute aggregates plus hour/day summaries indefinitely in SQLite WAL.
No historical backfill is fabricated. No pruning, schema-destructive migrations,
command lines, prompts, filenames, or model contents are stored.

App attribution: known path/cgroup patterns and inherited process ownership;
new processes/services are retained under discovered names, with optional registry
overrides. CPU uses process counters, RAM proportional set size where readable,
and GPU shares use deduplicated DRM engine-time deltas. Unreadable usage stays
unattributed. GPU attribution and whole-machine electricity are estimates.

The Windows read-only companion serves the local page and queries SQLite over SSH.
A separate authenticated metrics tunnel exposes the same GET API through Render.
Neither transport accepts SQL, shell commands, or history mutations from browsers.
Original app connections do not need to be stopped to add metrics.
# Navigation revision

Keep the dashboard's established colors and typography. Replace implicit wheel/drag
navigation with a visible toolbar on every plot: Earlier, Zoom, Later, Reset chart.
Scroll belongs to the document. Chart navigation uses already-loaded data and clamps
to the chosen range. Live refresh updates existing canvases, preserving focus and zoom.
Keep System / Unattributed explicit in the legend and each resource plot; historical
uncertainty must not be disguised as activity attributed to a known application.
