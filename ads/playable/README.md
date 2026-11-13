# Last Mile playable ad

`last_mile_playable.html` is a playable ad for Tapjoy and other MRAID 2.0 networks (ironSource,
AppLovin, Unity Ads, Liftoff, Mintegral). It's the real game in miniature: drag a route from the van,
deliver in stack order, the road tears up behind you.

- **Flow (about 20–40 s):** level 1 teaches the drag (a ghost finger shows the way); level 2 is the
  "which way round?" stack-order puzzle (going the wrong way gets stuck, then shows a hint); then the
  end card with a big **PLAY FREE**. A small PLAY FREE pill sits in the corner the whole time. The end
  card also comes up after 50 seconds or four failed tries, whatever happens.
- **Spec:** one self-contained HTML file, about 30 KB. No external requests (no fonts, images or
  scripts to fetch); everything's drawn on a canvas. Works portrait and landscape, any size.
- **MRAID:** includes the standard `<script src="mraid.js"></script>` hook (the SDK injects it), waits
  for `ready` and for the ad to be viewable before starting, pauses (and mutes) when it isn't viewable,
  and the CTA calls `mraid.open(url)`. Falls back to `FbPlayableAd.onCTAClick()` (Meta),
  `ExitApi.exit()` (Google) or `window.open` in a plain browser.
- **Sound:** small synthesized blips, only after the player's first touch (nothing autoplays).

## Before uploading

1. Set `CTA_URL` at the top of the script. Until the game is in the stores it points at the landing
   page with `utm_source=tapjoy&utm_campaign=playable`; swap in the App Store / Play link when live
   (or the network's click-tracking URL, if they ask for one).
2. Most networks want it zipped or uploaded as-is; Tapjoy takes the single HTML file. Test it in the
   network's playable preview tool (Tapjoy's and ironSource's both run MRAID).

`window.LM_TEST` is a read-only hook for automated checks (tile positions, level state). It does nothing
in normal play.
