============================================================
  MORRYNET COMPLETE SETUP - V67.2 (FIFTH STRATEGY: MASTER PLAN + STRICT SL INVARIANT)
  Single-folder Windows setup: embedded Python + MT5 bridge
  + terminal UI. No admin, no installs, no internet needed.
============================================================

QUICK START (3 steps)
---------------------
1. Extract the WHOLE MorryNet-Complete folder somewhere simple,
   e.g. C:\MorryNet-Complete  (avoid OneDrive, spaces, and
   non-ASCII paths; never run from inside the ZIP preview).
2. Open MetaTrader 5 and log in (enable the AutoTrading button).
3. Double-click START_MORRYNET.bat.
   -> A console appears (this is the supervisor - keep it open,
      you can minimize it). About 10 seconds later the terminal
      window opens by itself at http://127.0.0.1:8766/
   -> If Windows asks, allow python.exe through the firewall.

WHAT THIS CONSOLE IS
--------------------
START_MORRYNET.bat is the supervisor. It shows the LIVE bridge
log and keeps the bridge healthy:
  * If the bridge crashes, the console restarts it in 3s.
  * Type N to STOP the bridge.
  * Type R for an immediate clean restart.
  * Closing this window stops the bridge for good.
  * After 8 hours the bridge recycles ITSELF for freshness
    (exit code 81): the console instantly relaunches a clean
    copy. Your tuned settings live on disk (apex_bridge\,
    browser_profile\) and survive every restart. This is
    normal maintenance, not an error.

V67.2 - THE FIFTH TRADING STRATEGY: MASTER PLAN (NEW)
  The Master Trade Plan card from the first tab (the Super Terminal's unified
  decision layer: structure, liquidity, ICT/SMC, momentum, trend, volume,
  session, Nanoclaw, TA rating) now fires as an INDEPENDENT fifth strategy
  alongside V60 / SMC / 4-Ind / Fusion - same Entry/Stop/TP1/TP2/Runner plan,
  same master confluence gate as the card's EXECUTION lock, live + watchlist
  + backtest parity, its own MT5 magic range, and a 5th toggle chip in the
  Auto Trading tab (Master Plan).

V67.0 - THE STRICT STOP-LOSS INVARIANT (SAFETY POLICY)
----------------------------------------------------------
The bridge now enforces, by itself, at every point where a
stop-loss can move:
  * For a BUY : an existing protective stop is NEVER moved
    lower.
  * For a SELL: an existing protective stop is NEVER moved
    higher.
  * Moving a stop in the safe (tightening) direction is always
    allowed, and a position with no stop can always be given
    its first one.
  * Broker minimum-distance rules (stops/freeze levels) can
    only ever cause a request to be REFUSED - they never
    silently push a stop in the risk-WIDENING direction. The
    old behavior that re-widened a "too tight" stop to the
    2xATR floor every cycle is gone for good.
  * If the broker rejects a safe modification (e.g. market
    closed, invalid stops), the bridge REPORTS the rejection
    and KEEPS the existing stop. It never submits a wider,
    "easier-to-accept" replacement - it retries the same safe
    value next cycle.
This is enforced in BOTH engine copies (the Windows bridge and
the terminal's embedded engine), and the terminal's own ratchet
ladder was verified one-way (it can only ever tighten).

FRESHNESS RECYCLE (carried over from V66.4)
-------------------------------------------
After 8 hours of uptime the bridge exits with code 81 at a quiet
moment (never mid-order). The supervisor relaunches a clean copy
instantly - you should not even notice, except one line in the
console. Tuned configs are preserved on disk:
  apex_bridge\     bridge relay/tuning data
  browser_profile\ the terminal window's browser profile
                   (localStorage settings, layout, watchlists)
When upgrading to a newer MorryNet build, copy these two folders
into the new package to keep your tuning.

EXNESS / INDEX SYMBOL NOTES (improved in V67)
---------------------------------------------
Short index symbols with broker suffixes (US30m, US500m,
USTECm, DE30m, UK100m, JP225m...) now resolve correctly.
If an asset still shows "NOT RESOLVED" in the console, your
broker/account genuinely does not offer that index family -
check MT5's Market Watch (right-click -> Symbols) for what
your account actually lists.

TROUBLESHOOTING
---------------
* Nothing opens after ~15s? Read this console window - the
  live log tells you exactly what happened.
* "not connecting"? Run DIAGNOSE_CONNECTION.bat - a one-page
  report of the six things that can block a connection.
* Packages broken? Run REPAIR_APEX_RUNTIME.bat (installs from
  the bundled offline wheels - no internet needed).
* 24/7 unattended use (optional): run MORRYNET_WATCHDOG.ps1
  INSTEAD of this console (it supervises the same bridge and
  opens the terminal automatically; single-instance guarded -
  do not run both at the same time).

CONTENTS
--------
  START_MORRYNET.bat           <- double-click this
  SUPERVISE_BRIDGE.ps1         supervisor (live log + N/R keys + 81-recycle)
  OPEN_TERMINAL_WHEN_READY.ps1 opens the terminal window once the bridge is UP
  app\mt5_bridge.py            the bridge (V67.0 - strict SL invariant)
  MorryNet-Terminal-V67.html   the terminal UI (embedded engine: same policy)
  runtime\python\              embedded Python 3.13 (nothing to install)
  site-packages\               MetaTrader5, websockets, numpy (preinstalled)
  offline_wheels\              the same packages as .whl files + hash check
  DIAGNOSE_CONNECTION.bat      one-page connection diagnostic
  REPAIR_APEX_RUNTIME.bat      offline repair of the runtime/packages
  MORRYNET_WATCHDOG.ps1        optional 24/7 supervisor (alternative)
  CREATE_DESKTOP_SHORTCUT.bat   makes a "MorryNet Terminal" desktop shortcut
  MANIFEST.txt                  build manifest
  logs\                         bridge.log and friends appear here

Bridge version: V67.0_STRICT_SL_INVARIANT_FRESHNESS_V66 (unchanged)
Terminal version: V67.2_PENTA_CORE_MASTER_PLAN (fifth strategy added)
(WebSocket ws://127.0.0.1:8765 - Terminal/health http://127.0.0.1:8766)
