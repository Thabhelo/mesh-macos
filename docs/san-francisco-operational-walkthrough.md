# San Francisco Operational Walkthrough

This walkthrough validates Mesh in replay/training mode using the same incident snapshot path as live DataSF polling. Replay mode is clearly labeled as training data in the toolbar, sidebar, dashboard, and menu bar.

## Scenario

**SF Bay Bridge Surge Drill** demonstrates a Southern District call cluster around the I-80/Bay Bridge approach.

Usefulness claim: Mesh helps an operator detect a multi-agency Southern District surge and stage fire/EMS units before manually scanning raw calls would reveal the cluster.

## Script

1. Start the app and open the Dashboard.
2. Click `Start Replay` or `Start SF Replay Drill`.
3. Confirm the status badge reads `Replay` and the sidebar says `Replay Training`.
4. Step through the five replay frames:
   - Baseline SF Operations: normal posture, no surge.
   - Bay Bridge Approach Cluster: two high-priority calls appear near I-80 and 5th Street.
   - Southern District Surge Detected: fire and transit calls push the district above baseline.
   - Hazard Escalation: gas leak and assault raise the hazard score and keep Southern District first.
   - Resolution Tracking: the collision resolves while fire/gas risk remains.
5. Open the menu bar popover and confirm the active incident count, hazard score, and surge section reflect the replay frame.
6. Return to `Live Data` before using the app for production monitoring.

## What The Evaluator Should Learn

- What changed: a high-priority incident cluster appears in Southern District around the Bay Bridge approach.
- Why it matters: traffic, fire, EMS, transit, and infrastructure risks overlap in the same response area.
- Recommended action: stage fire/EMS units outside the congestion area and coordinate Southern District dispatch routing.
- Evidence: active incident count, surge alert, hazard score, district ranking, and incident priority explanations all move together.

## Screenshot Checklist

- Dashboard in `Replay Training` mode with the walkthrough card visible.
- Sidebar replay controls showing play/pause/reset/speed.
- Incident list showing Southern District priority explanations.
- Menu bar popover showing `Replay Training`, active count, hazard score, and surge alert.
- Final resolution frame showing one incident resolved while critical risks remain.
