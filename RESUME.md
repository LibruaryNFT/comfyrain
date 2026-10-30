# Comfy Rain — rain, weather and cozy ambience in World of Warcraft

**What this is:** a WoW addon that makes it look and sound like it is always raining,
because the client cannot be told to actually change the weather.

**Status 2026-10-12:** v2 installed to `_classic_beta_`. v1 was confirmed running in
Stormwind. v2 switches all audio and the drop sprite to Blizzard's own assets and stops
the rain indoors; needs `/reload` to pick up (no new files, so no client restart).

## Before 4 November (checked 2026-10-24 UTC)

1. Done: PR #21 merged as `30e2630` (closed #11); #18 closed as redundant. Main CI green.
2. Done: CurseForge token. Repo secret `CF_API_KEY` is set, and the GCP copy is
   `CURSEFORGE_API_TOKEN` in flowconnect-434715. It answered 200 on
   `wow.curseforge.com/api/game/versions` (a bogus token gets 403). The `v1.0.0` tag
   now uploads to CurseForge as well as GitHub.
3. Done 2026-10-23: retail loads, `/comfy status` answers, C_Weather reads the server's
   rain and Blizzard's sound FileDataIDs play (section "It loads on retail too"). The
   probe screenshots and the gallery re-shoot (PR #19) are optional, not launch gates.
4. #3 (does weatherDensity 0 stop the engine lightning) needs a real storm. It does not
   block launch.
5. Tag `v1.0.0` from `main` on **3 November** (moved from the 4th on 2026-10-26, report 2:
   it clears CurseForge moderation before players log in at 23:00 UTC on the 4th). It
   publishes, so it needs Justin's go on the day. Then check the file landed on CurseForge:
   the publish step has no CurseForge check of its own (only GitHub), so that is by hand.
6. Done 2026-10-24, all read back from the public page: the description has the "Which
   WoW" section (Forever and Retail, Classic not yet), the flat logo is the avatar
   (`avatars/2143/963`), and Roleplay and Artwork are listed. Those two categories were
   planned in `docs/curseforge-page.md` but had never been set; until now the page listed
   only Audio & Video.
7. CurseForge accepts both tags (checked 2026-10-24 via its API): Forever `1.60.1` and Retail
   `12.1.5`. Retail 12.1.7 is on the PTR (`wowt` 12.1.7.70493); add `120107` to the TOC when
   it goes live, or retail players see the addon as out of date.
8. **The page is Forever-only until the next upload.** Its one file, 0.9.2-alpha from
   20 Oct, is tagged Forever 1.60.1 alone, so the Retail listing in the CurseForge app
   does not show the addon. Any tag pushed now is tagged both from the TOC. Proposed: a
   `v1.0.0-beta1` tag now, which also proves the CurseForge upload before launch day.
   **2026-10-26: beta1 pushed from `edd3853` on Justin's go, and it failed before
   publishing.** The zip was good, but the release check wanted a flavour suffix
   (`-forever`) that the packager drops now the TOC lists two flavours. Nothing reached
   GitHub or CurseForge, so the page is still Forever-only, and v1.0.0 would have failed
   the same way. Fix: PR #38. Once it merges, push `v1.0.0-beta2` from main and read the
   CurseForge file's game versions back.
9. 2026-10-26: deep-research prompt for the launch plan, the audio roadmap and new
   features in the same mood, `docs/next-steps-research-prompt.md` ("make the absolute
   best addon we can"). It lists untested Blizzard rain soundscapes (coastal, plains,
   forest storm), drips and tavern chatter by FileDataID; none is probed on a client yet.
10. 2026-10-26: both reports are in, `docs/next-steps-research-report-1.md` and `-2.md`, and
    they are checked in the next section. Checking them turned up a launch bug: **#29, Volume
    does nothing in game.** Fixing it is the one code item before v1.0.0. The fix is PR #32
    (beds only; thunder and wind are #31), and #29 stays open until an ear test in a client.

## Launch plan (decided 2026-10-26, "ok do all of that")

**Before 4 Nov**
- [ ] PR #38 merged (Justin), then `v1.0.0-beta2` (item 8).
- [x] `/comfy probe volume` on Retail, 2026-10-30 on `dev-bb5c610`: the 15% clip was
      quieter and `kit_overlap` said yes. Result on #29; Forever half at the smoke test.
- [ ] PR #32 merged (Justin).
- [ ] CurseForge summary pasted (authors console, his login). Text is the Summary block in
      `docs/curseforge-page.md`.
- [ ] The 30-second clip with sound, on YouTube, first in the Media tab. Method and shot
      list: "The clip" in `docs/curseforge-gallery-plan.md`. Then the fresh stills. The
      shoot aid `~/comfyrain-shoot-2026-10-22/shoot-card.html` gets deleted after this.
      OBS configured 2026-10-26 (profile `ComfyRain`, websocket, `tools/obs_ws.py`); the
      agent records, Justin pastes one `/run` line in game.
- [ ] Forum reply in Blizzard's weather thread, text in `docs/launch-posts.md`. Justin posts it.
- [ ] v1.0.0 tag on 3 Nov (item 5).

**Launch week**
- [ ] 4 Nov 23:00 UTC, Forever smoke test: loads, `/comfy status`, rain and snow draw,
      `/comfy probe volume` (answers #29's Forever half: flag 0x20 and the 0.69 question),
      the #31 kit lines, and `/run PlaySoundFile(<id>)` for each soundscape and drip in #33
      and #34.
- [ ] 5 Nov: hotfix from whatever the smoke test finds, as v1.0.1.
- [ ] Every CurseForge comment answered, daily through 11 Nov (Invite-A-Friend week ends).
- Not this week: the r/wowforever post. Justin, 2026-10-26: "we arent making a new
  reddit thread yet, we will do tht later". Todo is #40; draft in `docs/launch-posts.md`.

**After launch, in this order** (label `after-launch`, none of it in v1.0.0)
1. #33 Rain soundscapes with Meander
2. #34 Indoor drips and the inn scene
3. #35 Fog
4. #36 Leaves, embers and sandstorm as one particle system
5. #28 Gamma brightening
6. #37 Music mode

## 2026-10-26: the next-steps reports, checked

What the reports claimed, and what we checked on 2026-10-26:

| Claim | From | Checked by | Result |
|---|---|---|---|
| `PlaySoundWithOptions` takes a SoundKit id, not a FileDataID | 1 | our probe log + wago.tools SoundKitEntry | **True, and it breaks us today.** Forever 70450 returned nil for FileDataID 838830, while kit 567 was accepted in the same run. The highest kit id on both clients is about 376k, and ours start at 538981. So every clip falls back to `PlaySoundFile` with no gain: #29 |
| Weather's indoor ambience does not play on Forever | 2 | Weather's GitHub releases | **Stale.** 0.1.1 fixed it with bundled 50%-volume files and says "I can't add volume sliders to the Forever version". A working slider on Forever would beat it |
| `C_CVar.SetTempCVar` landed in 1.60.1 | 1 | binary strings | **In the Forever `Wow.exe`, not in the Retail one** (control: `SetCVar` is found in both). Gamma on Retail still needs report 2's save-and-restore-on-logout. Untested: whether a temp Gamma stays out of Config.wtf. Added to #28 |
| Kaivax thread: 9.6k views, 807 likes, 214 posts (1); 93 posts (2, secondhand) | 1, 2 | Discourse JSON | 9,624 views, 807 likes, 208 posts, still open, last post 2026-10-03. **Report 1 is right and report 2 is wrong.** Liger's fog ask is post #7, verbatim. Post #18 asks for a way to turn weather *off* |
| HousingMusic 82.5K proves demand for music mode | 1 | CurseForge page | 82.6K, but it is keyboardturner's **Retail-only** player-housing playlist addon, not on Forever. FAME is at 366 (search, 2026-10-26). **Weak evidence**; report 2 ranks music 11th |
| Cinematic has no actual rain | 1 | CurseForge page | True. 9,055 downloads. Its only weather line: "rain, snow and sandstorms grey or colour the scene" |
| Launch 4 Nov, 3:00 p.m. PST (23:00 UTC) | 2 | Blizzard's Forever page and news posts | True |
| r/wowforever has 147,854 members (Subriff) | 2 | reddit `about.json` | **Unverified.** 403, and the control r/classicwow was also 403, so the method is blocked |
| Ship a `ComfyRain_Forever.toc` | 1 | our TOC | Not needed. `16001, 120105` already loads on both and the packager tags both |
| Suspend audio relaunches in combat | 1 | - | Rejected. The rain would go silent in every fight, and the report gives no reason for it |

**Where the reports agree, adopted:**
- Summary carries the searched words.
- Gallery leads with a clip that has sound.
- Beta tag now.
- Position as a companion: "Cinematic and Weather change how the world looks. Comfy Rain makes it rain."
- Rain textures plus a slow random gain drift ("Meander"), not three rain variants.
- A per-file loudness table.
- No `MuteSoundFile`.

Every gain-based audio idea in both reports depends on #29.

**Recommendation where they differ:**
- Upload v1.0.0 on **3 Nov**, not 4 Nov (report 2), so moderation is never in the way at 23:00 UTC.
- After launch, build the **soundscape picker and sequencer first** (report 2), not music mode (report 1), because music mode's demand evidence is a Retail housing addon.
- Summary to propose, from report 2, keeping "weather sounds" so the positive control still matches: "Cozy rain and snow anywhere, with Blizzard's own weather sounds, thunder, wind and a time-of-day colour grade. Rain ambience for questing, reading or AFK."
- The summary and every tag publish, so each waits on Justin's go.

**Soundscape availability, from the kit tables (not a play test):**
- Retail references every candidate file in a SoundKit.
- Forever's table references only 539134 (ForestStormy_Night), the SandStorm trio, the drips 596024/1402221/614975 and the 10.0 thunder strikes from 4883319.
- Coastal, plains, the other three storm beds, tavern walla and the cave loop are absent from it.
- Absent from the table is not absent from the client, so it still takes a `/run PlaySoundFile` on Forever launch night.

Icon: redrawn 2026-10-23 ("can we get a non-ai looking logo"), approved the same day
("flat drop is fine then"). One flat drop drawn from
geometry by `build/make_icon_tga.py`, which also writes `docs/logo.png` and the 400px
`docs/avatar.png`. The icon is round in the file now, and the square colour backing
behind it, which showed dark corners outside the minimap ring, is now a round texture.
Uploaded as the CurseForge avatar 2026-10-24 (item 6). The in-game icon needs a full client restart to show, not `/reload`.

## 2026-10-23 — One addon for every flavour: the window adapts, Classic still unlisted

"can we make one addon to work for all of them and change the ui for classic".

- **Same zip everywhere.** On a client without `PlaySoundWithOptions` the Volume
  slider is left out of the window. On one without `C_Weather`, Hide when game rains is
  left out. `/comfy volume`, `/comfy defer` and `/comfy auto` say why instead of doing
  nothing, and help drops the lines. Exposed as `ComfyRainAPI.Can`. Two `spec_ui`
  specs boot a "Classic world" with both removed, and use the full client as control.
- **Everything else the window uses exists on all three Classic branches.** Checked in
  Gethe/wow-ui-source, with `live` as control: BackdropTemplate, UIPanelButtonTemplate,
  the two texture paths, Settings.RegisterCanvasLayoutCategory and RegisterAddOnCategory,
  CreateColor and SetBackdrop. The addon compartment is retail-only. It is only TOC
  lines there, so Classic ignores them and the minimap button still works.
- **Not in the TOC yet.** Listing a flavour is one edit:
  `11509` (Era 1.15.9), `50504` (MoP 5.5.4) and `20506` (Anniversary 2.5.6), all read from
  the branch heads. It waits for one in-game load, which needs game time. One sub
  covers all three. Issue #20.

## 2026-10-23 — It loads on retail too: one TOC line, `16001, 120105`

"can this addon work on all versions of wow... get it to work on retail so i can properly
take screenshots".

- **`## Interface: 16001, 120105`**, one line, no second TOC. Forever honours comma lists:
  Auctionator ships `120105, 16001, ...` and loaded in the beta with out-of-date addons
  off. A `_Mainline.toc` was avoided because the Forever binary also knows the Mainline
  suffix and which one it prefers next to a bare TOC is unmeasured. `spec_boot` fails if
  either number drops out.
- **API check per client** (`tools/api_audit.py --exe`): retail 12.1.5.70575 and
  `_forever_` both 0 missing. Classic Era 1.15.9 is missing C_Weather and
  PlaySoundWithOptions. Blizzard's API docs (Gethe/wow-ui-source; control: `live` and
  `forever` have both, and the docs agree with the Era binary) show MoP Classic and TBC
  Anniversary lack the same two. On those three, the addon would load, but the volume
  slider would be dead, Hide when game rains would never fire, and `/comfy auto` would
  always say no weather. Untestable without a sub, so they are not listed. Fixes and the
  gate are in issue #20.
- **CurseForge will tag releases Retail as well as Forever.** Read from packager v2.6.1
  `release.sh`: `toc_to_type` maps each Interface value on its own, `16???` to forever
  and anything unmatched to retail.
- **It did not run on retail before this.** Gotfrag (Sargeras) was in the world 15:38 to
  15:42 today with `ComfyRain: enabled` in `AddOns.txt`, and no `ComfyRain.lua` was
  written to `SavedVariables` (the beta, same declaration, writes one every session).
  That was with interface 16001 only, so the out-of-date gate is the likely cause;
  unproven.
- **It loads now.** 2026-10-23 evening, retail 12.1.5.70575: `/comfy status` answered
  and read the server's rain at 0.80 through C_Weather. The status said "(bundled
  audio)", but `_retail_/WTF/Config.wtf` had `Sound_EnableAllSound "0"`: the game was
  muted, so every clip was refused, Blizzard's and ours alike. That exposed a real bug:
  any refusal flipped the bed to the bundled loop for the rest of the session and
  dropped the under-layer, so a Ctrl+S mute in the rain cost the layered sound until
  `/reload`. Fixed: with the game's sound switch off the bed waits and retries, and the
  status says the sound is off. **Blizzard's FileDataIDs play on retail.** 23:39 the same
  night, sound back on (no `Sound_` lines left in Config.wtf, which only stores
  non-defaults; `weatherDensity` in the same file is the grep's control), `/reload`,
  and `/comfy status` read `sound on` with neither suffix. A refused bed prints
  "using the bundled one" and adds "(bundled audio)", and neither appeared.

## 2026-10-23 — Testing while the beta is down: retail's free tier

"beta isnt available to test on... we dont have an active retail subscription, is there
any way we can test more or do screenshots".

- **Beta offline since 13:02 today** (wowforeverstatus.com, control: 1425 of 1580 samples
  online over 72h). It was down Oct 21 12:40 to Oct 22 07:18 and came back.
  `forever-watch.service` started 13:12 to chime when it returns (10h cap).
- **Retail is free to level 20 with no subscription** (Starter, or Veteran for lapsed
  accounts), and Blizzard says addons work on it. This account reached retail character
  select on 2026-08-25 (`_retail_/Logs/Connection.log`).
- Retail is the same engine as Forever (`Wow.exe`, D3D12), so its screenshots are ground
  truth for how our art and blend modes draw. They say nothing about Forever-only API or
  the realm's weather.
- Installed with `./install.sh _retail_`. The TOC lists retail's interface now (section
  above), so no client setting is needed; the `checkAddonVersion` override that was
  briefly in `_retail_/WTF/Config.wtf` is gone. Retail runs RenderScale 0.65,
  weatherDensity 0.
- **`/comfy probe shots` is 13 shots now**: every intensity of both weathers, then dusk
  and night. The spec checks each shot photographs the state its name says (mutation
  tested: a mislabelled light snow fails it). Files land in `_retail_/Screenshots`, the
  manifest in `ComfyRainDB.probe.shots` after `/reload`.
- Open: compare those shots against `tools/perceive.py`'s renders, pair by pair.

## 2026-10-23 — Weather, Time of Day, Sound; "Hide when game rains"

"i dont think we are even able to pause in real weather... that doesnt make sense to me
that we can stop 3d rain", and "time of day after rain & snow, maybe rename that to weather".

- **The setting never stopped the game's rain and cannot.** `db.defer` hides OUR overlay
  while the game's own rain or snow falls. The label "Pause in real weather" read as
  pausing theirs. Now **Hide when game rains** (20 chars, inside the 7.0 px/char spec);
  the tooltip, the "Use mine" note ("Game rain here, so ours is hidden.") and a new README
  row say it cannot touch the game's weather.
- **Detection is proven live, from `SavedVariables/ComfyRain.lua` `calib`:** 2026-10-20
  07:24:01 Elwynn, the console line `Weather changed to 1, intensity 0.674720` and
  `C_Weather` = rain in the same second; 69 yielded/resumed switches 10-20 to 10-23
  (Duskwood, Westfall, Riverglades, Wetlands, Stormwind), `weatherDensity` 3. Closes the
  "not yet confirmed in a running client" notes on both sources below. The real console
  line has a comma and **no `recID`**, unlike LibForecast's pattern.
- Riverglades flips ours on and off every 10 s to a few minutes as you cross subzones:
  the game's weather is per subzone. Works as built; watch for complaints.
- **Window order is Weather, Time of Day, Sound.** Heading "Rain & Snow" is "Weather"
  again (Reset Weather). `SECTION_ORDER` (share-string key order) is unchanged on purpose.
  New spec pins the heading order.

## 2026-10-23 — Every setting tested for a difference a player can see or hear

"why do we keep mentioning things are broke ie the light snow, but you said u tested
things, can u test things urself more thoroughly, all the things". The suite checked
that each setting sent the renderer the right numbers; light snow did, and drew what
normal drew. Nothing checked what the numbers looked like with the real art.

- **`tools/perceive.py`** renders every choice the window offers (from
  `test/dump_scenes.lua`) with the built art, over a dark ground and a snowfield, and
  fails any pair a player could not tell apart. Thresholds and both negative controls
  are in its docstring and `test/README.md`. In CI (`assets` job).
- **`test/spec_perceive.lua`**: all 18 controls in the window, clicked, land exactly
  where typing their command does, and somewhere other than where they started.
- **What it found, fixed:** heavy rain, monsoon and heavy snow drew the lighter step's
  flakes brighter, the light-snow flaw again. Each now draws a denser near sheet
  (`rain-near-heavy`, `rain-near-monsoon`, `snow-near-heavy`): the lighter sheet plus
  more elements from their own seeds, so every existing sheet is bit-identical. Every
  window choice now passes: 0 pairs a player could not tell apart.
- **check_art's size ruler was wrong, fixed.** It read straight down a pixel column, so
  it measured where a slanted streak crossed a column (the 190px bars it was written for
  read 73px and, at today's tiling, passed) and chained touching flakes into one (heavy
  snow read 17% and failed). It now follows each element at its own slant and cuts
  touching ones at deep valleys. Held against every element's true size, rasterised one
  at a time: the bars read 187px (true 187) and fail at 28%; every current sheet reads
  within 20% of its truth and passes. A built-in control (a 200px slanted streak whole,
  two touching flakes split) aborts the run if the ruler breaks either way.
- **Margin to know:** monsoon 11.6% and heavy snow 11.5% against the 12% ceiling, both
  over their true sizes (9.6%) because dense sheets stand two elements end to end.
- Not done: an in-game screenshot sweep (`/comfy selftest`) as ground truth for the
  renderer model itself. Everything above trusts that perceive.py draws as WoW does.

## 2026-10-23 — How other addons look native: research, nothing changed yet

"can we download some addons and check how they get their UI to look more like the
vanilla wow ui?" Read Ace3 (AceGUI widgets, behind most addon config windows), Leatrix
Plus (a hand-built panel) and Blizzard's own UI source for this client (Gethe
wow-ui-source, branch `forever`; `_classic_beta_` is the Forever client, iface 16001).

- **Ace3 and Leatrix use the same 1.12-era art we already do**: `UI-DialogBox-Border`
  and `-Header`, `UI-SliderBar-*`, `UI-CheckBox-Up/-Check`, `UIPanelButtonTemplate`.
  There is no trick in them we are missing. Small things they have that we lack:
  `UI-CheckBox-Highlight` on hover, and Ace3's Heading draws `UI-Tooltip-Border`
  rules either side of a centred gold label.
- **The game's own windows are `ButtonFrameTemplate` / `PortraitFrameTemplate`**, a
  NineSlice over the `UI-Frame-Metal-*` atlases. On Forever (game type `camelot`) the
  client ships its own art under those atlas names: `Camelot/NineSliceLayoutOverrides.lua`
  says "the art made for Camelot doesn't match the exact size of the Mainline Standard
  art" and re-offsets the corners. So a frame built on those templates draws Forever's
  own window chrome, whatever that is, and keeps matching it if Blizzard changes it.
- Also loaded on camelot per the tocs: `UIPanelCloseButtonDefaultAnchors` (28px, set by
  `Camelot/SharedUIPanelTemplates.lua`), `MinimalSliderWithSteppersTemplate` (the Options
  slider, arrows both sides), `UICheckButtonTemplate`, `SettingsListSectionHeaderTemplate`,
  and the full `Settings.RegisterVerticalLayoutCategory` / `CreateCheckbox` /
  `CreateSlider` / `CreateDropdown` API, which draws controls exactly as Esc > Options.
- **Unverified at runtime.** All of the above is source; per the 2026-10-16 rule every
  template is `pcall`-probed and cached because an unknown name raises.
- **Recommendation:** rebuild the window's frame on `ButtonFrameTemplate` (no portrait)
  plus `UIPanelCloseButtonDefaultAnchors`, today's art kept as the fallback when the probe
  fails. That is the one change that makes it match Forever's own windows rather than
  1.12's. Controls second, if the frame lands.

## 2026-10-23 — Light snow is fewer flakes, not fainter ones

"snow light and normal dont seem diff". Measured on the near sheet (visible = peak
contrast at least 5/255 over the ground, positive control rain light/normal/heavy):
light drew 552 flakes, normal 618, heavy 628. Alpha only changed brightness (median
13 vs 26 vs 37 /255), because 87% of the near sheet's flakes already show at 0.30.
Speed differs 18%, which is physically right for snow, so it cannot carry the
difference the way rain's 1.8x does.

- **`snow-near-light.tga`**: the same flakes with a 45% keep mask from its own RNG
  (`scatter(thin=)`), so the other three sheets are bit-identical. Light snow's near
  layer draws it at 0.52: 320 visible flakes at 21/255, against normal's 618 at 26.
  Far stays 0.34, so light's depth haze is still fainter too.
- Wired into check_art SHEETS and both workflows' asset lists; release force-adds by
  glob. New spec "gives light snow fewer flakes"; draw golden updated (two rows).
- Heavy had the same flaw against normal (628 vs 618, brighter only); fixed with a
  denser sheet, see "Every setting tested" above.

## 2026-10-23 — No scene rows: Rain & Snow, then Time of Day, each starting at Off

"Do we need those presets at the top, cant we just use the rain & snow type of ui,
and then under that time of day, im confused cause theres redundancy", and "maybe we
dont need icons for type".

- **The two button rows are gone.** Type steps Off / Rain / Snow and is the weather's
  only switch; Time of Day's Mode steps Off / My PC clock / Shift by hours / Fixed
  hour ("Server time" renamed Off). The scenes live on as `/comfy preset <name>`,
  README updated.
- **No icons anywhere**: the Type well's frost-spell picture, the well's icon slot and
  the dead `Button:SetIcon` are deleted (`SetIcon` out of api_audit OURS).
- Specs: the preset-button tests now drive the selectors or the typed preset; new
  "has no row of scenes" (positive control: the same lookup finds Use mine) and
  "puts no picture anywhere" (positive control: the scan finds a spell icon once one
  is drawn). The harness `w:button(text, nth)` gained `nth`.
- **Open:** `docs/curseforge-shoot-card.md` on docs/gallery-plan names the old buttons.
- **Open:** a player whose last scene was Overcast has `scale 0` saved and no slider to
  undo it; Reset Rain & Snow does. Unchanged by this commit, worth knowing.

## 2026-10-23 — The window holds still, and stopped narrating

"We choose a setting and it shifts the UI a lot... if we choose normal light then dusk",
and "we choose overcast, why do we need drawing normal rain".

- **Nothing appears, vanishes or moves on a press.** Hour and Strength are greyed (and
  deaf to the mouse) in modes that do not use them instead of hidden; the "weather is
  off" line is gone; the note row is always laid out, empty or not. The window is
  centre-anchored, so every height change used to move its top too.
- **The status sentence is gone.** The lit buttons are the readout. The one text line
  now speaks only when the screen disagrees with them: under a roof, real rain (with
  Use mine), a cutscene, or the realm already at the held hour. Each fits one line at
  the 7.0 px/char rate.
- New specs: one walks every button, mode, note and indoor state and asserts the window
  height and the Volume row's y never change (positive control: a taller row does move
  them); one asserts no note after Overcast/Storm/Off/Night/Normal.
- `SetActive` added to `tools/api_audit.py` OURS (our row method, not client API).

## 2026-10-23 — The top of the window is two rows: Weather and Light

"If we wanted no weather but wanted it day or night", the old Scenes / Light only /
Server Light / Turn It All Off / Show rain & snow set could not answer by reading it.

- **Weather:** [Off] [Cozy] [Storm] [Snow] [Overcast]. **Light:** [Normal] [Dusk] [Night].
  Each row owns one thing and leaves the other alone; night with no rain is Off + Night.
  Both rows are fifths of the width. Off runs `/comfy off`, Normal `/comfy time off`.
- **Dusk and Night no longer write `enabled = false`.** That side effect is what made
  Storm then Night throw the storm away. The disjoint-keys spec has no `enabled`
  exception any more.
- **Removed:** the Turn It All Off pill (`/comfy stop` still works and is in help), the
  Server Light pill (now Normal), the "Show rain & snow" checkbox (Off is the switch;
  stepping Type or Intensity turns the weather back on). The status line has the whole row.
- The section heading Weather is now **Rain & Snow** ("Reset Rain & Snow"), so the top
  caption is the only thing called Weather.
- No Day button, still: brightening is capped at LIFT_CAP and the sky keeps its stars.
  Normal gives the realm's own daylight when it is day.
- Shoot card: photo 4 is a redo anyway; the header's button list needs the new rows.

## 2026-10-23 — The settings window lost its five tuning controls

"We shouldn't allow a user to change the settings of the rain, that's too granular... if
we remove the options it might make it cleaner and less intimidating." Gone from the
window: **Drops, Fall Speed, Darkness, Wind, Follow camera zoom.** Weather is now the
master switch, Type, Intensity and "Step aside for real weather". Sound and Time of Day
are unchanged.

- The settings still exist underneath. The scenes write scale, speed, gloom and gust on
  every press, and the slash commands still reach all five, unadvertised. The README no
  longer lists `alpha`, `speed`, `dim` or `gust`.
- The UI tests that used Drops, Darkness and Wind as their example slider now use Volume
  and Strength; the checkbox layout tests use "Step aside". A new spec fails if any of the
  five comes back into the window.
- Photo 4 of the shoot (window over live rain) is a redo anyway, so it gets the new window.
- Then, from an in-game screenshot: "Step aside for real weather" was cut off to "Step aside
  for real we...". A row label has 148 px and the client's font measured 5.8 to 7.4 px a
  character against the mock's 5.2, so no spec saw it. Renamed **Pause in real weather**,
  and a new spec checks every row label at 7.0 px a character (fails on the old label).
- The Sound section's switch is first now, as Weather's is, and reads **Play sounds**
  instead of "Sound" under a heading that already says Sound.

## 2026-10-23 — The rain falls 1.8x faster: the layers were too far away

"The rain looks like it's falling too slow", after the pass below. Measured off the
Stormwind clip (`/tmp/shootcode/flow2.py`, FFT cross-correlation on high-passed frames):
near 0.89 screen heights/s against 0.92 designed, far 0.46 against 0.45. So the code did
what it said. What it said was wrong in **level**, not ratio: far 1.05 / near 1.07 put the
near layer at about 5.5 m, a depth nobody chose. Report 1 says the eye locks onto streaks
1 to 5 m away. Both layers now sit at 3 m and 6 m: `LAYERS` far 1.925, near 1.954 (x1.833),
same 2.03x screen ratio.

Near layer at slider 1.0, screen heights per second: Cozy 0.71, normal rain 1.30, heavy
1.57, Storm 1.69, snow 0.25 to 0.34, blizzard 0.30 vertical and about 3.4 along the slant.
Cozy is back near the 0.81 that was liked originally; Storm is well under the 3.81 that was
too fast. Lua only, so `/reload`. Both loops now repeat at about 0.51 s, still to detune.

The camera-turn test measured the turn on top of the fall drift, and at the new speed the
drift happens to land on a whole sheet. It now compares a turned world against an unturned
twin, and fails when the yaw term is zeroed.

**Shoot status:** Stormwind photos 2, 3 and 5 are good. Redo clip 1 (old speed) and photo 4
(UI was hidden). Park the mouse in a corner; it is in every frame so far.

## 2026-10-22 — The fall speeds are derived now, not tuned by eye

"It feels our rain falls too quickly" turned out to be two separate errors, and the second
one needed research we had never done. The art was researched (drop shape, streak-length
distribution, snow morphology); the **motion** never was. Per-intensity speeds and layer
speeds were all tuned by eye.

Two deep research reports came back against
[docs/motion-realism-research-prompt.md](motion-realism-research-prompt.md). Both are saved
verbatim: [report 1](motion-research-report-1.md),
[report 2](motion-research-report-2.md). **Read
[docs/motion-research-reconciliation.md](motion-research-reconciliation.md) first** — it
records which report won each disputed point, the four places report 2 is checkably wrong,
the full before/after speed table, and what is deferred.

Shipped in this pass:

- **Rain now spans 2.37x light to monsoon, not 4.7x.** Monsoon's near layer came down 53%.
  Normal rain is the anchor and did not move. Terminal velocity goes as roughly the square
  root of drop diameter, and the median-volume diameter only runs 0.8 mm to 2.5 mm across
  everything rain does.
- **Snow spans 1.35x, not 2.9x.** Heavy snow came down 59%.
- **Blizzard falls at the same vertical rate as light snow**, which is the physical truth.
  Its speed is sideways: slant 78 to 85 degrees, and `make_snow_tga.py` bakes the gale
  streaks at 85 to match. Along-streak travel is 1.86 H/s.
- **Scene preset speed multipliers are all 1.0.** Cozy and Storm were 0.9, Snow 0.8. Those
  were taste corrections on top of numbers that were wrong by a factor. Cozy lands within
  3% of where it was, so the preset most people sit in is unchanged.
- **Camera yaw no longer has parallax on it.** Rotation is depth-independent — a yaw of
  omega moves every ray by omega — while we were scaling it 0.25 / 0.9 / 1.0 per layer and
  shearing the three layers against each other on every turn. `PARALLAX` is gone.

Still open, both art-coupled and both their own pass:

- **Rain slant is 7.5 degrees for every intensity and should be 22 to 56.** Needs
  `make_rain_tga.py` re-baked at the new angle, or sheared UVs via the 8-argument
  `SetTexCoord`. A sheet whose streaks point one way and whose travel points another reads
  as a filter over the screen; that is the bug the blizzard sheet had at 62 degrees.
- **Running should tilt the field, not speed it up.** `(1 + runSpeed * 0.3)` is the wrong
  vector treatment: 7 m/s through 9 m/s rain is a 38 degree tilt and only +26% speed.

Lower priority, no art dependency: `GUST_FOLLOW` should be ~0.7 s for rain and ~0.1 s for
snow rather than 6.0 / 2.2 / 1.0 per layer; near and far both loop at ~0.94 s and one
should be detuned; `ZOOM_RATE`'s 20% first-person speed boost has no physical basis.

**The gallery shoot has to happen after the remaining motion work**, or the GIFs ship the
old motion.

The gale TGA changed bytes, so this one needs a **full client restart**, not a `/reload`.

## 2026-10-22 — The rain and snow stopped being a pattern

Storm's streaks, the snow and the blizzard all read as fake. Cozy did not, and Cozy is
the lightest preset, which was the clue. Two independent deep-research passes over the
overlay reached the same diagnosis from different directions: **the elements were drawn
well and the population they were drawn from was wrong.** Done in two commits.

### Phase 1, no new art: three structural fixes

Full reasoning is in the commit message for `eb51056`. In short:

| Was | Now | Why |
|---|---|---|
| `density` per intensity, 0.58 monsoon to 1.35 light, multiplying tilesY | one `tiling` per weather (rain 1.35, snow 1.20) | it was **inverted** — heavier weather drew fewer, larger streaks. Marshall-Palmer: 32 visible drops/m³ at 1 mm/h against 477 at 25. Closes #11 |
| whiteout = white quad, ADD, cap 0.10 | BLEND at 0.22, cap 0.30 | ADD cannot reduce contrast until it clips. Koschmieder's whiteout is contrast collapse towards sky luminance |
| blizzard `slant` 1.9 (62°), sheet baked at 78° | `slant` 4.7046 = tan(78°), `speed` 2.58 → 1.15 | the streaks pointed one way and the sheet slid 16° off it. 62° is 1.5 m/s of wind, not a gale |

Cozy is byte-identical by design: the new `tiling` is pinned at the old light values, so
everything moves *towards* the preset he already likes.

### Phase 2, the generators: `build/precip.py`

The sheets drew a few hundred near-identical elements on a jittered grid, with a caste of
deliberately bright ones. All four of those are wrong, and the new shared module is the
four fixes. Its docstring carries the derivations.

- **Placement is independent uniform, not a jittered grid.** A grid gives every element
  its own cell and so deletes exactly the close pairs and holes a Poisson field is made
  of. *That lattice was the starfield*, not the flake drawing. The old docstring defended
  the grid because uniform placement "reliably leaves bald patches and clumps" — it does,
  and that is the point.
- **Sizes are a power law, not a uniform range.** Projection gives p(s) ∝ s⁻⁴ for one
  physical size; real size variation flattens it to ~3.0-3.2. Overwhelmingly tiny
  elements, a thin tail of large close ones. A uniform range makes them all the same size.
- **Brightness is lognormal and there is no bright caste.** One element in ten at ×1.9 is
  precisely the landmark the eye re-identifies when the sheet tiles, so the caste was
  buying the repeat it was meant to disguise. At σ 0.6 the 95th percentile is already
  2.7× the median with nothing being special.
- **Blowing snow is spatially intermittent**, via a log-Gaussian Cox field (FFT-built, so
  strictly periodic and the sheet still tiles). The gale gets patches, stretched 150px
  along the wind against 55px across.

Per-drop and per-flake variety followed: every streak now gets its own longitudinal
profile from 2-4 random lobes (Garg-Nayar found **no** universal streak profile), width
correlated with length because both are the same 1/z, and the hex modulation is confined
to the largest 10% of near flakes where it can actually be seen.

**Mean alpha is held within 2% per sheet on purpose** — counts went up and `a_med` was
solved back against the old means, so this is a change of distribution, not of density.

### Two art checks, and the control that mattered

`check_art.py` is now eight checks. The new ones are **landmarks** (brightest pixel
against the 99th percentile of lit ones) and a rewritten **uniformity**.

Uniformity's control is now the sheet's own blobs, lifted off it by connected-component
labelling and re-scattered at uniform random: identical elements, known-random placement.
Two earlier controls were wrong and both are recorded in the docstring, because each
looked right:

- a **binomial over pixels** assumed pixels were independent. They arrive in elements tens
  of pixels across. It survived only while placement was a grid, and failed snow-near at
  12.1× for doing the right thing once placement went Poisson.
- a **32px block shuffle** was worse: it is *inert*. Shuffling preserves the distribution
  of block densities, so a sheet with a quarter wiped out shuffles into a sheet with a
  quarter of its blocks empty. It passed a deliberately bald quadrant, which is the one
  defect the check exists to catch.

The statistic matters as much as the control. Overall coverage spread is dominated by
where the few largest elements landed, so the hole test is one-sided on the **emptiest
128px cell**; at 64px cells a wiped quadrant does not separate from clean art at all.

Positive controls, all three passing: old art fails landmarks 1.94-2.18× against a 1.5
threshold (new art ~1.15-1.25); a wiped quadrant fails the hole test on all five sheets,
as does a hole of a single 128px cell; the shipping sheets are clean. 292 tests pass,
worst element 9.9% of the frame against the 12% ceiling.

### Open

- **Not yet seen in-client.** New TGAs need a **full client restart**, not `/reload` — WoW
  reads the addon file list once at startup.
- Near snow is still `ADD`. One report wants it BLEND; left alone until the above is
  judged on screen.
- A **fourth precipitation layer** at irrational tile-period and wrap-rate ratios
  (1:√2:√3:φ²) pushes the near-recurrence to ~8,200 base wraps, a sixfold gain over three
  layers. Only if the 4 Nov date holds.

## 2026-10-20 — The presets no longer darken a world that is already dark

Gallery shoot on the beta client, Goldshire at night. **Every preset came back at median
luma 10-25 out of 255**; a readable CurseForge thumbnail wants 60-100. The cause was not
the realm's hour, it was the addon stacking a daylight-calibrated darkening on top of it.

- `SceneLuma()` — Rec.709 luma of `LightAt(RealmHour())` times the grade's multipliers.
  What the frame actually looks like, not what the clock says.
- `NightEase()` — maps that onto a gloom multiplier. **1.0 in full daylight**, easing to
  `NIGHT_FLOOR = 0.35` at the curve's darkest (`NIGHT_LUMA = 0.37`, the 03:00 keyframe).
- Applied at the one place the gloom amount is computed, so the gust modulation and the
  indoor factor both inherit it.
- The 20s `todTicker` now calls `ApplyAlphas()`. Nothing presses a button between dusk and
  midnight; that tick is the only thing that can notice.

**Daylight is the identity case on purpose.** The 2026-10-15 sweep calibrated the preset
curve at noon and this may not disturb it. Exactly one golden line moved — the "held at
midnight" case, `gloom 0.8290,0.8556,0.9164` → `0.9402,0.9495,0.9707`. A new spec asserts
all four weather presets are flat across the lit hours so the next tweak cannot move them.

The floor is a fraction rather than zero because a storm that stops darkening after dusk
is its own kind of wrong.

**Rejected:** `/console gamma 1.6` + `brightness 60`. Outside the addon, and it washed the
frame out rather than fixing it — "thats weird and too bright not sure why u dont just
make the presets or whatever nicer". Correct. Client brightness is not a substitute for a
preset that behaves at night, and a CurseForge screenshot taken at non-default gamma is a
screenshot of something the player will not get.

**Still open on brightness:** `NIGHT_FLOOR = 0.35` is one calibration pass, not a measured
optimum. Re-shoot the Goldshire snow frame and measure before locking it.

## 2026-10-20 — Pre-launch review pass: the player's words, and three more ways in

An external review of the window and the addon, run against a screenshot of the live
settings panel. Three of its recommendations were already satisfied in the repo
(cinematics are handled, both frames are already `BACKGROUND` strata, `DEFAULTS.channel`
is already `Ambience` — the reviewer read `Master` off a screenshot where it had been
changed by hand), and the rest are below. Two commits.

**Commit 1 — labels, percentages, a live scene marker.**

- **The word Weather appeared three times meaning three things.** Now: the heading is
  Weather, the master checkbox is "Show rain & snow", the rain-or-snow selector is
  "Type", and the per-section reset reads "Reset Weather" through a new `RESET_LABEL`
  display-name map rather than by renaming the internal `look` section key.
- Six other renames into what a player would say: Visibility → Drops, Zoom Response →
  Follow camera zoom, Yield to Real Weather → Step aside for real weather, Channel →
  Volume follows, Share → Share / Import, and the four `TIME_MODES` labels (Off → Server
  time, My Clock → My PC clock, Shifted → Shift by hours, Held → Fixed hour). Keys and
  commands are untouched, so no saved profile moves.
- **`realm` → `server` in every user-facing string.** Forever is realmless.
- **Multiplier sliders read as percentages.** `1.30` is a number out of a config file and
  does not say what it is 1.30 *of*; `130%` does. `Pct`/`Shown` in `UI.lua`, and `fmt`
  may now be a function. `0` reads as "Off", which is a state and not a quantity. Hour
  keeps its own units.
- **The active scene is marked with a 2px bar**, not a tint on the label: the two pill
  flavours rest at different text colours and the native one rests at gold, which is this
  window's reserved heading colour. The marker drops off on the first slider move, which
  is the honest answer. Light and weather markers can both be lit at once, because the
  two kinds compose.

**Commit 2 — the "nothing happened" row, and three more ways in.**

- **`FixNote(db)` puts the reason and the fix directly under the status line.** Two cases
  where the addon is working exactly as designed and looks broken doing it:

  | State | What the row says | Button |
  |---|---|---|
  | Standing aside from the game's own storm | "Real rain here, so the game's own is showing." | **Use mine** → `/comfy defer off` |
  | Grade asking for the hour the server is already at | "The server is already at that light, so this adds nothing yet." | none — nothing to undo |

  One button, reused, reading its command at press time so it can never fire the previous
  note's fix. The status line's yielding phrase came down to "Real weather here, so this
  stood aside" because that line does not wrap.
- **`GradeShift()` / `GradeIsFlat()` extracted from `UpdateTimeOfDay`** so the window can
  ask whether the grade is doing anything visible. `GRADE_FLAT = 0.02` lives with the
  arithmetic, not in the window: the window asks the question and does not get a vote on
  what "nothing" means. `State()` exposes `lightFlat`.
- **Flatness is clock-driven, so the 20s `todTicker` notifies on it.** It is the only
  window state that changes with nobody touching a control, so no control press is ever
  coming along to correct it. A third of a minute late is fine for a sentence about the
  hour; never is not.
- **Addon compartment** (`## AddonCompartmentFunc` + Enter/Leave in the TOC,
  `ComfyRain_Compartment` in `UI.lua`): left-click opens the window, right-click toggles
  the weather, matching the minimap button. A client that passes no button argument gets
  the harmless one.
- **`Bindings.xml`**: "Weather on or off" and "Open the settings window", under a Comfy
  Rain header. No default keys — a default on a weather addon takes a key away from
  whatever the player had it on. Loaded by filename, so it is deliberately *not* listed
  in the TOC.
- **`ComfyRain_Settings()` registers a stub page** in the client's own addon list, with
  one button through to the real window. A stub and not the real panel: this window is
  movable, closes on Escape and is opened by a slash command, and a frame hosted in the
  settings canvas is none of those. Whether this build hosts a panel at all is still
  unverified (Phase 1 item 7) and cannot be asked any more, so the whole path is guarded
  and pcalled end to end, registers once, and a client with no `Settings` table is a spec
  (`noSettings` on the mock).

286 specs green, api_audit clean at 123 client APIs.

**Not taken from the review, with reasons:** "Hide in dungeons & raids" (a new saved key
and a new failure mode three days from launch, and `/comfy off` already exists); the
collapsed "More ▸" advanced fold (the scene rows already answer "where do I start", which
was the actual complaint the fold was proposed for); the Sound section reorder.

## 2026-10-20 — Six scene presets, in two kinds

"can we not have like quick preset buttons, this is riduclous and not user friendly at
all" — said after a session spent dragging four sliders to get one screenshot, and it is
the right read. The window had grown to roughly fifteen controls across three sections
with no starting point in it, so the first thing a new installer sees is a mixing desk.

`PRESETS` in `ComfyRain.lua` (beside `SECTIONS`) is the single source of truth. Six
scenes in two kinds, each kind writing a fixed set of keys: `weather` presets write
`enabled`, `weather`, `intensity`, `scale`, `speed`, `gloom`, `gust`, `sound`, `thunder`;
`light` presets write `enabled`, `timeMode`, `timeFixed`, `timeStrength`.

| Preset | Kind | What it is |
|---|---|---|
| `cozy` | weather | light rain, quiet, no thunder |
| `storm` | weather | monsoon, dark, wind and thunder |
| `snow` | weather | steady snow |
| `overcast` | weather | `scale 0` + `dim 2.0`: dark sky, nothing falling. The composition it took a whole session to discover |
| `dusk` | light | hour 19 at strength 0.9, weather off. Golden hour |
| `night` | light | hour 22 at full strength, weather off. Cold blue |

- **Two kinds writing disjoint keys** is the design. Weather presets write the nine
  look-and-sound keys and never touch the clock; light presets write the clock plus
  `enabled = false` and never touch a look key. So they compose: Night then Cozy is a
  light rain at ten at night. A spec walks the table and asserts both halves of this.
- **The same key set within a kind** is the load-bearing bit. Seven here and eight there
  leaves a setting behind from the previous press, and the same button then gives two
  different screens. A spec asserts Cozy-after-Storm equals Cozy-from-fresh.
- **Storm is `speed 0.9`, not 1.3.** "storm feels too fast and fake to be honest".
  monsoon's own calibrated fall speed is 2.76, the highest in the table; a multiplier on
  top put it at 3.59, and past some rate a 2D sheet reads as a scrolling texture rather
  than as rain. Density and dark sell heavy rain, not pace. Gust came down 1.6 → 1.2.
- **There is no `day`, deliberately.** Brightening is an ADD quad clamped at `LIFT_CAP`
  because it can raise the black level but cannot restore contrast, and the skybox keeps
  its stars. A button called Day that does almost nothing is worse than no button;
  `/comfy time off` is the honest way back to the realm's light.
- **Deliberately not touched:** volume, channel, indoors, defer, zoom, minimap. How this
  player likes the addon to behave, not what it looks like.
- A light preset's chat line always names `/comfy time off`, because a dark screen with
  no rain on it is the exact state this addon has already been reported for.
- **`dim 2.0` for overcast, not a number near the preset.** `GloomAmount` lands every
  preset on exactly 1.0 at slider 2.0, so the result is as dark as the addon goes no
  matter which intensity it arrived from.
- **UI:** two pill rows at the very top of the window, above the Weather heading, one per
  kind, built by iterating `ComfyRainAPI.Presets` — adding a scene is one table entry and
  the window follows. Slot width is a fixed quarter of the inner width rather than a
  share of that row's count, so the two-button light row is not two giant buttons under
  four small ones. Each press runs `Run("preset <key>")`, so it is the typed command like
  every other control, and the tooltip teaches it.
- Also `/comfy scene` as an alias, and an unknown name prints the real ones.

278 specs green, api_audit clean at 123 client APIs.

## 2026-10-20 — Darkness now actually goes dark

Shooting store screenshots at the Stormwind gates, the scene would not get dark enough
and the only control that could do it was `/comfy time`. That is a different feature.
The author: *"to change the brightness we shouldnt be setting that with time and strength of
time"*. He is right, and the reason was arithmetic:

- The gloom layer lerps the frame towards the weather's `tint`, `0.55 / 0.62 / 0.78` for
  rain. That tint is calibrated to what real weather does to **daylight**, so it is a
  wash, not darkness.
- Monsoon's preset already sits at `g = 0.95`, so `dim 1.2` and `dim 2.0` were four
  percent apart. The right-hand half of the slider had travel and no effect.

Fixed by giving each weather a `deepTint` (rain `0.38 / 0.44 / 0.62`, snow
`0.46 / 0.52 / 0.70`) and having the slider's top half walk the tint itself down to it,
in `GloomColor`. **At `dim <= 1` the arithmetic is byte-identical to before** — the
2026-10-15 screenshot sweep calibrated the preset curve at the default and none of it
moved. The golden file diff is two rows, both `darkness full`.

Snow stops short of rain on purpose: lying snow is the brightest thing in a scene, and a
dark snowstorm reads as a rendering bug.

**Darkness without rain or sound already works**, by composition: Visibility 0, Darkness
up, sound toggle off. Nothing new was needed, but nothing advertised it either, so the
Visibility tooltip now says what 0 gives you and a spec pins the combination. `/comfy
status` also calls out `alpha 0` in words, because every other line of it says "on" and
the number alone reads as a broken addon.

**The light grading no longer needs the rain switched on.** `UpdateTimeOfDay` was gated
on `db.enabled`; it is now gated only on `timeMode`. The case is a player a long way
from their realm — the Australian on a US realm who wants night at their own 10pm and
no weather at all — and making them run rain to get light was the addon refusing the
one thing asked for. `/comfy time local` is the whole answer, from a cold start.

That coupling existed for a day, added after *"my screen is too dark and I can't turn
off the changes it made"* (live play, 2026-10-19). **The fault there was an effect with
no visible cause, not an effect that outlived the rain**, and that is fixed three
separate ways now: `/comfy status` leads with the mode, the window names the held hour
every refresh (`LightPhrase`), and `/comfy stop` kills everything including the grade.
`/comfy off` now prints that the light is still held and points at both switches. Two
specs pin it, one for the curtain surviving `off` and one for `stop` taking it down.

**In the window, with no slash commands:** untick **Weather effects**, then set
**Time of Day > Mode** to **My Clock**. Two clicks. The Time of Day section stays on
screen and keeps working when the master switch is off, which is the point.

Decoupling the light created a new way to be confused, so the window now says it: with
the weather off, a line under the master switch reads *"Weather and Sound below do
nothing while this is off. Time of Day still works on its own."* It appears only in that
state. Darkness sits under Weather and goes inert; Time of Day sits below it and does
not, and a player moving the wrong one of those concludes the addon is broken.
`harness.lua` grew `panelText()` for this — every word the window is currently showing,
with hidden rows excluded — because there was no way to assert on panel copy before.

**Still true, and it is a limitation not a bug:** the gloom layer is a fullscreen MOD
multiply, so it dims lamps and torches by the same factor as everything else. It cannot
make a light source glow. Compositions whose whole appeal is warm lamps against cold
rain are the ones this addon cannot win, and screenshots should not lead with them.

## 2026-10-20 — the CurseForge logo

`docs/logo.png` is now three blue drops falling with trails behind them, cropped at 512
from an image-model contact sheet and committed. It replaces the
rendered-from-`make_icon_tga.py` version.

**Drop proportions are a hard constraint, not a style note.** The first pick was a
diagonal cell whose drops had a long tapered neck over a bulbous base. The author, instantly:
*"its too close to a penis rather than a rain drop"*. He is right and it cannot be
unseen. Any future drop art keeps classic teardrop proportions — wide round bottom,
short point on top, neck no longer than the bulb is wide — and gets looked at by a human
before it ships.

**How it was chosen, because the method is the reusable part.** Four models were each
given the same ideation prompt (nine distinct concepts, not nine renders of one), then
the surviving concept was re-prompted for nine variations of itself. Every candidate was
then cropped and resampled to a true 64x64 and judged *there*, not on the 1536 sheet:

- Painterly scenes die at 64. Two of the four models only produced scenes, whatever the
  prompt said, and every one of those cells turned to mush.
- Splashes, crowns and columns of small drops also die. What survives is one bold mass,
  two colours, and no thin wiry detail.
- **Clever metaphors are worse than the literal thing.** A flame inside a raindrop
  ("comfy" + "rain") reads in a WoW icon vocabulary as a Fire or Frost spell. The author:
  *"why would it be a flame drop, thats stupid"*. He was right. The addon draws rain, so
  the icon is rain.
- A single large droplet is the most legible cell on the sheet and was still rejected: it
  says *water*, which is every mana and frost icon in the game. The diagonal and the
  streaks are what make it say *rain falling*.

**The in-game icon is now cut from the same art.** `build/make_icon_tga.py` no longer
rasterises a drop from a model; it crops one out of `docs/logo.png`, so the addon list,
the minimap button and the CurseForge page are all the same picture and cannot drift
apart. The script keeps its CLI, its 64x64 power-of-two 32-bit TGA output and its
`--preview` panel, so the release workflow is untouched.

It is a crop and not a straight downsample for a measured reason: the logo's three
diagonal drops smear into one blur at the 20px the minimap button draws. The crop
(`CROP` in that file, in the logo's own 512 space) isolates the middle drop so the icon
keeps one big subject. **After any logo change, re-run with `--preview` and look at the
20px panel**, because the crop box is hardcoded to where the drop currently sits.

## 2026-10-20 — the CurseForge submission, and what the first real zip was carrying

**Two LLMs consulted** (Gemini 2.5 Pro and GPT-5; Groq 403'd, so this is two of three
and not a consensus of three). Both independently said the same three things:

| Question | Verdict |
|---|---|
| Publish the CurseForge page today? | **Yes, today.** Moderation is a human queue and a first-time author may wait longer than the 15 days left. Placeholder art does not get a project rejected; an unapproved page on 4 Nov is fatal |
| Last hours of client access | Both ranked the TOC flavour test **#1**. It turned out to be already answered on disk, see the section above |
| The 4 Nov / 11 Nov split | Everything already live-tested ships 4 Nov. They differed only on blackout code: Gemini said collapse the split, GPT-5 said hold blind-written code for 1.1.0. **Taking GPT-5's**, which is also the house rule already in this file |

GPT-5 added the point neither the 13 Oct consult nor I had: **attach a real file**, because
a project with no downloadable file sits in the moderation queue longer and reads as
abandoned to whoever approves it. Hence `v0.9.1-alpha`, marked Alpha, not Release.

**Unzipping the published artifact found a leak that the repo could not show.** The first
alpha, `v0.9.0-alpha`, shipped `docs/` and `dr-prompt-name-final.md` to players: 194KB of
API dumps, a 3D-feasibility note and an internal argument about what to call this addon,
all landing in an AddOns folder. `.pkgmeta`'s ignore list is hand-maintained and never had
them. Deleted that release and shipped `v0.9.1-alpha`.

**The guard is now shape-based, not a list of names.** The release workflow fails on any
`.md` in the zip that is not README or CHANGELOG, and on a `docs/` directory. A list of
filenames only catches the notes that already existed when somebody last remembered to
update it; this catches the next one.

**Page copy is written and paste-ready:** `docs/curseforge-page.md`, one fenced block per
CurseForge field.

## 2026-10-20 — the TOC flavour question was already answered, on disk

**#4 needed no restart. It had already run, twice.** The flavour probe staged in
`_classic_beta_` wrote its answer on 2026-10-19 and nobody read it.

```
_classic_beta_/WTF/Account/916451#1/SavedVariables/DuskfallFlavour.lua
  loaded = "_Forever"   build = "70374"   interface = 16001
  written 2026-10-19 06:23, and again in the .bak at 05:34
```

**The suffix this client prefers is `_Forever`.** The probe shipped ten competing TOCs
(bare, `_Forever`, `_Vanilla`, `_Classic`, `_Mainline`, `_Standard`, `_Cata`, `_Mists`,
`_TBC`, `_Wrath`); exactly one writes `loaded`, so the method could have returned any of
ten values and returned the same one across two separate client sessions. That is the
positive control, and it settles the R1-vs-R2/R3 contradiction recorded at line 1418 in
favour of a filename suffix.

**It does not change what we ship.** `ComfyRain.toc` is bare, with `## Interface: 16001`,
and it loads on this client every day - which is its own positive control that a bare TOC
is not refused. The suffix only matters for a single zip covering several flavours, and
this addon is Forever-only. Keep the bare TOC; the suffix is now a known-good fallback
rather than an open risk.

## 2026-10-20 — it rains inside Ironforge, because the client says Ironforge is outdoors

**Reported:** "its weird how it rains inside ironforge though."

**Measured, off his own SavedVariables rather than from a new reading** (300-entry
doorway log, `db.where`):

| uiMapID | zone | IsIndoors / IsOutdoors readings |
|---|---|---|
| 1455 | Ironforge | `true/false` **and** `false/true` |
| 1453 | Stormwind City | `true/false` 44, `false/true` 44 |
| 1429 | Elwynn Forest | `false/true` 9, `true/false` 1 (the inn) |
| 1431 / 1433 / 1436 | Duskwood / Redridge / Westfall | `false/true` only |

Ironforge reads `IsOutdoors true` in the Great Forge. That is simply false - it is a
cavern with a lava-lit ceiling and there is no point in the city where a drop of rain
could land. The matching Stormwind, Elwynn, Duskwood, Redridge and Westfall IDs are
exactly the canonical Classic uiMapID table, which is the positive control that the
table applies to this client and that 1455 is really Ironforge.

**Deference does not help here.** Blizzard runs no weather in Ironforge, so there is
nothing to stand aside for; ours is the only rain in the room.

**Fix: `SEALED_MAPS` in ComfyRain.lua**, consulted by `Sheltered()` ahead of the
`IsIndoors()`/`IsOutdoors()` pair.

- Keyed on **uiMapID, never `GetRealZoneText()`** - that string is localised, and a list
  of English zone names would leave this broken for every non-English player, which is
  the kind of bug that never gets reported.
- Ships with two entries: **1455 Ironforge, 1458 Undercity**. Deliberately short. A map
  only belongs on it if it is interior end to end, so that forcing it can never take
  rain away from somebody who should have seen it. Stormwind, Orgrimmar, Darnassus and
  Thunder Bluff have real open districts and are **not** on it.
- **It reports shelter; it does not seize the decision.** A sealed map still runs through
  `IndoorMode()`, so `/comfy indoors on` still draws rain in Ironforge. That is the
  player's call.
- **`/comfy indoorhere`** (alias `roof`, `off` to undo) adds the current map to a per-user
  `db.indoorMaps`. The built-in list is permanently incomplete - no API answers "is this
  map interior" - so the Deeprun Tram, cave cities and every private-server map have to
  be handed to the player rather than guessed at. Deliberately **not** in `PROFILE_KEYS`:
  it is machine-local state, not a shareable look setting.
- `/comfy where` now prints `(map has no sky)` when we are overruling the client,
  otherwise the line reads `IsOutdoors yes -> SHELTERED` and looks like a bug.
- `/comfy bug` now carries `map<id>` and `sealed`.

**Three specs in `spec_visuals.lua`, all mutation-checked:** removing the check from
`Sheltered()` fails 2; making a sealed map force rain off instead of reporting shelter
fails the `indoors on` spec; ignoring `db.indoorMaps` fails the `indoorhere` spec. The
first spec drives Elwynn with the same flags as its positive control, so it cannot pass
on a build that just stopped drawing rain everywhere.

**Open:** the Deeprun Tram's uiMapID was not shipped because it could not be verified
from his log or the client binary, and a guessed ID is worse than a missing one. It is
covered by `/comfy indoorhere` until somebody reports it.

## 2026-10-20 — bug reports: what to ask users for, and how CurseForge handles it

**CurseForge has no issue tracker.** A project page has a comments section and a set of
link fields; bug tracking is whatever URL you put in the **Issues** field in project
settings. So that field points at `https://github.com/LibruaryNFT/comfyrain/issues` and
GitHub stays the single tracker. Comments on the project page will still happen and have
to be watched, but they are not the system of record.

**An in-addon reporter is allowed, and cannot submit anything.** There is no HTTP, no
socket and no clipboard write in WoW's Lua — by design, and it is why every addon's
"report a bug" is a box of text you copy. So the most a reporter can ever do is assemble
the line and hand it over already selected.

`/comfy bug` does that, reusing the existing share box. One line, because the box is a
single-line EditBox and because one line is one Ctrl-C where a block is a drag:

```
ComfyRain 2.0.0 | wow 1.60.1.70450 iface 16001 | enUS | 1916x1080 @0.711 |
ComfyRain1:enabled=1;weather=snow;... | at Elwynn Forest/Goldshire 48.2,63.2 |
in0 out1 shel0 | draw1 hear1 yield0 | real=rain@0.67 dens3
```

| Field | Why it is in there |
|---|---|
| version, client build, interface | the first two questions of every triage |
| locale | a mangled or missing string is usually this |
| resolution and UIParent scale | the whole look is geometry; "it looks wrong" is unanswerable without it |
| the full profile, in import format | whoever triages can paste it into their own client and be looking at the reporter's exact configuration in one step |
| zone / subzone / coords | a bad doorway is findable; "somewhere in Stormwind" is not |
| `in0 out1 shel0` | all three shelter reads, never the conclusion alone — every shelter bug so far has lived in the gap between the first two |
| `draw/hear/yield` | what the addon believed it was doing at that moment |
| `real=...  dens...` | the client's own weather and whether it was being drawn |

No character name, no realm, no guild. Nothing leaves the client.

**Also fixed in the same pass:** the window said "normal rain, not drawn" while standing
aside for a real storm, which is the same "everything says on and nothing is drawing"
report as the indoor one, with no visible cause at all. It now says *"The game's own
weather is falling, so this is standing aside."* And `Enter` over the share box used to
mean "import this as a profile", which fired on the diagnostic line too — the single most
likely keystroke after a Ctrl-C. It is guarded now.

## 2026-10-20 — our rain fell through the Stormwind gate arch, and the fix is to stand aside

Reported from live play under the arch at Stormwind's gate: our rain falls straight
through it. **It always will, and no amount of code changes that.**

| | Blizzard's rain | ours |
|---|---|---|
| Where it lives | world-space particles | a flat sheet in front of the camera |
| Occluded by the arch | yes | never possible |
| Can an addon draw the first kind? | — | no: `ModelSceneFrame` does not exist on this build (probe, 2026-10-20) |

A better indoor test is not the answer either. `/comfy where` under the arch reads
`IsIndoors no  IsOutdoors yes  -> open sky`, so the client itself says there is no roof,
and that pair is the entire API surface for the question.

**So the addon defers instead of occluding.** When the client is already drawing real
precipitation here, ours stops. Under the arch you now see theirs, correctly occluded by
the geometry. It is on by default — the one default in this addon that argues with the
name on the tin, and it is right, because where the real thing exists it is simply
better than ours.

- Gated on **two** conditions, not one: `C_Weather` reporting precipitation at intensity
  above zero, **and** `weatherDensity > 0`. `weatherDensity` has been 0 on this machine
  for most of the addon's life, and on such a machine `C_Weather` reports rain the client
  is not drawing. Deferring on `C_Weather` alone hands the player an empty sky.
- Debounced asymmetrically and in the opposite direction to shelter: **1s to yield, 3s to
  come back.** A storm ramps across zero at both ends, and a dying one dips and recovers;
  our sheet flickering back in for a second is worse than a few seconds of no rain.
- `/comfy defer on|off`, a **Yield to Real Weather** checkbox under the look section, and
  a line in `/comfy where` reading `game's own weather: rain at 0.67, density 3 ->
  STANDING ASIDE`, so "everything says on and nothing is drawing" has a visible cause.
- Seeded on `PLAYER_ENTERING_WORLD` rather than left to the ticker, so hearthing into a
  storm does not show a second of our sheet first.

Mutation-checked three ways (ignoring `yieldNow` fails 3 specs, dropping the
`weatherDensity` guard fails 1, removing the debounce fails 1). The specs assert on the
overlay, not on layer alpha: deference stops the effect at `ShouldRain`, while "indoors"
scales the layers and leaves it running, so a layer-alpha assertion would pass on a build
that deferred nothing.

**Open:** whether deference should also silence our audio bed. Right now it stops the
whole effect, sound included. Blizzard's own rain has its own loop, so the player is not
left in silence, but that has not been checked by ear against a real storm.

## 2026-10-20 — what the probe answered

Run on build 70450. Full output: `python3 -I tools/probe.py report`.

| Check | Answer |
|---|---|
| `screenshots` | **no.** Ten requested, zero landed; the 40 taken by hand on 2026-10-15 sit in the same folder and prove the folder was never the problem. `Screenshot()` is protected on this build, so `docs/preview.gif` has to be recorded from outside the client. |
| `model_3d` | **no.** `CreateFrame("ModelSceneFrame")` raises *Unknown frame type*, and `Model:SetCameraDistance()` raises *Not using a custom camera*. Real 3D weather from an addon is closed off. |
| `mute_self` | **yes, and it is a problem.** Muting Blizzard's rain files mutes ours too, because we play the same files. The suppression plan needs a different file. |
| `finish_event` | **no.** The SoundKit variant of the finish event fires; the FileDataID variant does not. |
| `weather_cvar` | writes land. `weatherDensity` read **3**, not `"0"` — the claim elsewhere in this file that it is still 0 is **stale**. |
| `geometry` | 1916x1080, aspect 1.774, UIParent scale 0.711. **Not 21:9**, so issue #5 is only half-answerable from this session. |
| `mute_reload` | **contested.** One run said the mute survived the reload, the next said it was dropped. Reapply on `PLAYER_LOGIN` regardless. |
| `savedvars` | yes, the token survived a reload. |
| `c_sound`, `sound_params`, `settings_panel`, `weather_model`, `ambience_musicoff` | all yes; the id key is `soundKitID`. |

**Screenshots, the working method:** `Shift`+`PrintScreen` is the GNOME binding for an
instant full-screen capture with no dialog, landing in `~/Pictures/Screenshots`. Plain
`Print` opens the picker UI instead. Scripted capture from outside is **not** available
on this box: GNOME Shell refuses `org.gnome.Shell.Screenshot` over D-Bus
(*Screenshot is not allowed*) and an XWayland root grab via `ffmpeg -f x11grab` returns a
pure black frame.

## THE 30-MINUTE ROUTE — do this before 21 October

Everything client-gated is now a GitHub issue (`gh issue list --label client-gated`),
so nothing here depends on this file or on a chat session surviving. Issues #1-#6.

The route below answers five of the six in one pass.

### Step 1, once, when you log in

```
/comfy watch on
/comfy probe
```

**What `watch on` does, and why it is first.** Every look setting in this addon is a
guess, because `weatherDensity` has been 0 on this machine since before the addon
existed and the client has therefore never once drawn Blizzard's own rain here. There is
nothing to compare ours against. `watch on` turns Blizzard's rain back up and then waits:
real weather is server-driven, cannot be summoned, and arrives when it arrives. **It
shouts in chat when it happens, so there is nothing to watch for.** It runs underneath
the rest of the half hour, which is why it goes first.

When the shout comes, it asks for three screenshots in a row: theirs, ours on top of
theirs, theirs alone. That triple is the only calibration this addon will ever get.

It was called `calib` and still answers to it. The name was the single most confusing
thing in the command list, and it also used to raise the graphics settings without ever
putting them back. `watch off` now restores them.

### Step 2, the walk

Walk Stormwind, slowly, and go **under** things rather than past them:

| Stop | What it tests | Issue |
|---|---|---|
| Trade District awnings, the fruit stalls | NEITHER-flag awnings in the open world | #1 |
| The canal bridges, standing under the arch | shelter with sky visible on both sides | #1 |
| The inn, the barbershop | known-bad from live play; confirm both are fixed | #1 |
| Dwarven District tunnel and the mine mouth | cave entrance, the other NEITHER shape | #1 |
| Cathedral doorway, stop **on** the threshold | the flicker case: in and out inside 3s | #1 |
| The open street inside the Keep's walls | the false positive that would kill the feature | #1 |
| Any real storm: `/console weatherDensity 0` | does engine lightning stop too | #3 |

**Type `/comfy where` while standing under each roof.** The addon writes a row on every
committed transition by itself, with coordinates, and that is enough for doorways that
work. It is not enough for the bug being hunted. An awning the engine reads as open sky
produces **no transition at all**, so it produces no row: the exact failure case is the
one the automatic log is blind to. A Goldshire pass on 2026-10-19 logged three clean
two-state transitions and zero awnings, which says nothing either way about awnings,
because an awning that failed would have looked identical to one that was never visited.
`/comfy where` forces a reading wherever you are standing.

### Step 3, when you are done

```
/comfy watch off
/reload
```

`watch off` puts the graphics settings back. `/reload` is what writes SavedVariables;
they are not written continuously, so skipping it loses the whole walk. Then on this box:

```
lua tools/where_report.lua
```

Two still outside the route: #4 needs a full exit and relaunch with the flavour probe
staged into `_forever_`, and #5 is eyeballing the quads at several `UIParent:GetScale()`
values, which cannot be done headlessly because the overlay is parented to `WorldFrame`.

## 2026-10-20 — the repo is `comfyrain` now, and it was rebuilt to get a name out of it

`LICENSE` line 3 carried the author's **legal name** in a **public** repo that was
days from a CurseForge listing. Everything else on the account is pseudonymous - commits
use the `@users.noreply.github.com` address, there are no public SSH keys, the profile
carries no real name, and all 118 hits for the surname across the account are in private repos -
so the one line that was not pseudonymous was the one line that undid the rest.

Fixing the working tree was not enough, and neither was rewriting history. A force-push
**orphans** old objects rather than deleting them, and GitHub goes on serving them to
anyone with the 40-character SHA. Verified anonymously, with no token:

    curl https://raw.githubusercontent.com/LibruaryNFT/duskfall/cfc6eb9.../LICENSE
    -> the legal name, still being served

So the repo was deleted and recreated. That is the only self-serve way to destroy the
orphans; GitHub Support can purge instead, but that is days and a message to a human.

**It came back, in the write-up of its own fix (found 2026-10-20).** This section quoted
the offending line verbatim, three times, which put the exact string the repo was deleted
to destroy back into the public HEAD of the replacement repo. Introduced by `745e6f6` and
carried by every commit since.

**The rule, so it is not re-derived next time: never write the legal name down in a public
repo, including when describing why it must not be there.** Say "the legal name". A
redaction that quotes what it is redacting is not a redaction.

| | |
|---|---|
| Old | `LibruaryNFT/duskfall`, created 2026-10-19, 0 stars, 0 forks |
| New | `LibruaryNFT/comfyrain`, 93 commits, both tags, both branches |
| Carried over | all 10 issues with labels and numbers intact |
| Backup | `~/backup-duskfall-2026-10-20/` - full pre-rewrite mirror + `issues.json` |

Those three orphan SHAs now return 404 anonymously and a fresh clone has zero hits, with
"rain" at 168 as the positive control that the scan finds things when they are there.

This closed **#7** as a side effect: `HOMEPAGE` and `## X-Website` already said
`comfyrain`, so the URL in the addon's own About box works for the first time.

**The standing rule this leaves:** the copyright holder on anything published under
`LibruaryNFT` is `LibruaryNFT`. MIT does not care whether the holder is a legal name or a
handle, and a pseudonymous account is only as pseudonymous as its least careful file.

## 2026-10-19 — the indoor rain was playing all along, at 12%

**"if we go indoors shouldnt we still hear the rain though - its not doing that now."**
The engine was never wrong here: `ShouldRain()` stays true indoors, the bed relaunches on
the doorstep, and the mock shows clips playing the whole time. The number was wrong.
`INDOOR_HEAR` was 0.35, and the under-layer rides at 0.35 of the bed again, so the quiet
layer landed at `0.35 x 0.35 = 0.12` of the Ambience channel. Under an inn's own ambience,
under its music, and on top of whatever the player's Ambience slider is set to, that is
not muffled rain, it is nothing.

`INDOOR_HEAR` is now **0.55**. Still a clear step down from standing in it, and a step you
can hear happen.

The three specs that covered this all asserted a ceiling and no floor, which is why none
of them noticed: `lt(v, 0.4)` is satisfied by 0.12 and by silence-but-for-a-whisper
equally. They now assert a **band**. Quiet has a floor, or quiet is off with extra steps.

**"we need the minimap icon thing to be bigger circle."** The button was 31px, LibDBIcon's
default, with a 53px ring and a 20px hole. Those four numbers are one measurement of one
piece of art, so there is now a single `MINIMAP_SCALE = 1.25` and everything derives from
it: button 38.75, ring 66.25, hole 25, art 27.5, offset (1.875, 0.625). Nudging the button
size on its own is exactly how the art ends up off-centre again, because the offset is a
fraction of the button.

The icon spec was asserting the four literals, which would have turned every size change
into a spec edit. It now asserts the *ratios* against the button's actual width, plus
`k > 1.0` so the button can never quietly shrink back to the cramped default. Mutation-
checked three ways: dropping the duck to 0.12 fails, scale back to 1.0 fails, and growing
the button while leaving the art offset at 1.5 fails on the centring.

**The raindrop needs a full client restart, not `/reload`.** `icon.tga` is a new file and
WoW reads the addon's file list once at startup; a texture added while the client is
running silently does not load. That is why the drop had not appeared.

259 specs green.

## 2026-10-19 — twenty-six clips nothing could stop, and a checkbox arguing with itself

Two reports, both of a control that did not control anything.

**"i couldnt turn off my weird sounds ... i had toi disable audio and then reenable."**
A bed loop is the clip relaunched `BED_OVERLAP` seconds before it ends, so for a moment
two copies run and the slot holds two handles. `SlotPlay` trimmed the list back to two
with a bare `table.remove(slot.handles, 1)` — which dropped the oldest handle off the
front **without stopping the clip it belonged to**. From the third relaunch onwards every
loop leaked one running clip out of the only record of it that existed, and `StopBed`
could then only stop the two it could still see.

It is a slow leak, which is why it was so hard to believe: for the first minute `sound
off` works perfectly. Measured in the mock, which only expires a handle when the spec
gives the file a length:

| after | clips live | still live after `sound off` |
|---|---|---|
| 5s | 2 | 0 |
| 60s | 7 | 3 |
| 300s | 30 | **26** |

Thunder had the same hole for a different reason. `Strike()` called `Play()` and threw
the handle away at the call site, so a clap — several seconds long and the loudest thing
the addon makes — was unstoppable by construction, however briefly the player had been
outside. It now goes through a `thunderSlot`, stopped by a `StopThunder()` that is kept
separate from `StopBed` on purpose: `StartBed` calls `StopBed` to relaunch the loops at a
new gain, and a clap chopped off halfway because somebody walked through a doorway sounds
like a bug.

`SlotPlay` also no longer appends a nil handle. Assigning nil to `t[#t+1]` is a no-op in
Lua, so a client that plays a clip and hands back no handle used to silently push the
real handles along by nothing — and if that ever happened the trim would have evicted
live handles early.

Covered by "can stop every clip it ever started, however long it has been raining" in
`spec_math.lua`. Both halves mutation-checked: restoring the silent drop leaves 30 clips
live, restoring the discarded thunder handle leaves 3 after `sound off`.

**"should be the same button but the checkbox turns it on or off."** The master switch
relabelled itself between "Weather on" and "Weather off" as it was clicked. A ticked box
next to the words "Weather off" can be read as off, or as "off is ticked", and the two
are opposites — the checkbox was arguing with itself. The label is now fixed and the tick
carries the state, which is what a tick is for. It reads "Weather effects" rather than
"Weather" because the section heading above it and the rain/snow selector below it are
both already called that, and three things with one name in 330 pixels is worse than a
slightly longer label. `tools/preview_panel.py` updated to match. Covered by "keeps the
master switch's label still and lets the tick carry the state".

259 specs green.

## 2026-10-19 — a new icon: a lit window, and a hole that was never centred

> "can u make us a new comfyrain icon the current one doesnt fix in the circle
> properly and it needs to be more comfy and maybe bigger"

Three separate problems behind one complaint.

**The minimap button was never using the icon.** `BuildIcon` drew six colour quads —
a dusk gradient with little streaks on it — which is the design `make_icon_tga.py`'s own
docstring had already rejected: "at 20 pixels looks like grey noise with a pink line in
it". The 64x64 raindrop TGA made to replace it went into the addon list and the button
was never switched over. It now draws the art file.

**The hole in the ring is not centred on the button.** With the 53x53
`MiniMap-TrackingBorder` anchored TOPLEFT on a 31x31 button, the opening is 20px across,
centred at `(17, -15)` from the top-left corner — 1.5px right and 0.5px *up* from the
button's own centre. The art was painted at `(-1, +1)`, a 2.5px error on a 20px disc: it
overhung the brass on the left and left a crescent of bare map on the right. Drawn at
22px now, so the mask's soft edge tucks under the brass lip rather than meeting the map.

**The icon is a raindrop. One, for both weathers.** A warm lit cottage window was tried
first and rejected on sight — "make it a rain icon or something". It read as comfy and
did not read as weather, and an icon's first job is to name the thing it opens. A
six-armed crystal for the snow setting was built next and dropped the same day — "do the
rain drop i guess first one". Nothing is lost by that: the tooltip and the panel both
name the running weather in words, and an icon that changes under the player is a worse
readout than one they can learn.

The drop is 11% larger than before (`r` 0.258 → 0.287, as big as it goes while keeping
its outline clear of the minimap's crop). One bold silhouette with a dark outline over a
glow is the lowest-frequency contrast in the frame, and so the last thing a downsample
destroys.

**The backdrop is radial now, not a horizon.** The old drop sat on a straight horizon
band with ground under it, and a straight band inside a circular crop becomes a chord:
that composition only worked as a square, and the minimap does not give it one. It is a
warm glow behind the subject falling off into the corners, with the vignette following
the same circle the crop does.

Two renders now, `icon.tga` and `icon-snow.tga`, so the button keeps the live weather
readout it had as quads; off is the same picture desaturated and dimmed. Reference
render at [docs/icon-preview.png](docs/icon-preview.png) — 64px and 20px, both weathers.

`.pkgmeta` needed no change (the assets are gitignored and force-added), but the
`icon-snow.tga` filename was added to the CI non-empty check and the release zip's
contents check, both of which enumerate files by name.

## 2026-10-19 — rain you can hear and not see, and an off switch that wasn't

> "we reload and hear rain but dont see anything, the construactsols are reytarded we
> cant even turn oiff the raiun sound, but we love the UI of this so keep that"

Two bugs, both confirmed mechanically before anything was changed. A throwaway probe
through the mock printed, with `indoors = true`: `far` alpha `0`, overlay `shown false`,
the bed still playing, and the settings window still saying **"Drawing normal rain."**

| Bug | Cause | Fix |
|---|---|---|
| Hears rain, sees none, window insists it is drawing | the status sentence was computed from `db` alone, and the window was never told when the world moved | `ComfyRainAPI.State()` + `WeatherPhrase()`, and `ComfyRain_Refresh` calls `changed()` on a real change |
| Sound off still plays rain | `ApplySuppression`'s `active` included `db.sound`, so turning ours off unmuted the realm's own ambience loops | dropped `db.sound` from `active` |

**The sound bug was a swap, not a failure.** Our bed did stop — the mock shows two stop
events for two plays. Unmuting Blizzard's `AMBIENCE_LOOPS` in the same breath handed the
realm's rain straight back, so the player unticked Sound and went on hearing rain. Off
has to mean silence, and the box they just unticked is the visible cause, which is the
only thing the old rule was protecting against. A cinematic and `indoors off` still hand
the loops back: there ComfyRain has stood down rather than been asked to be quiet, and a
realm muted by an addon drawing and playing nothing is silence with no visible cause.

**A status line that describes the settings is not a status line.** Under a roof the
overlay is hidden and the bed keeps playing — that is the design — but the settings were
truthfully on, so the sentence was true about the settings and a lie about the screen.
`State()` is recomputed on the spot and caches nothing, so it cannot go stale between
the poll and the refresh. The window now says `Indoors: rain heard, not drawn`,
`Indoors: nothing drawn`, or `Paused for the cutscene`.

**Why the repaint is guarded.** The indoor poll runs a `Refresh` every 0.3s; `changed()`
only fires when `draw`, `want` or `indoorsNow` actually move, so a doorway costs two
repaints rather than three a second. Anything the player clicks already calls `changed()`
on its own way out, so this only covers the world moving: doorways, cutscenes, loading
screens.

The UI from the previous section is untouched, as asked.

256 specs green. Both fixes mutation-checked: restoring `db.sound` to `active` fails the
suppression spec, hard-wiring `WeatherPhrase` past `State()` fails the new status spec,
and so does severing the `changed()` call.

## 2026-10-19 — the column, the fonts, the glass, and a switch that waited

> "we clicked turn it all off and it didnt change quick enough
>
> also please check the ui, it doesnt appear exactl like the wow options
>
> i think we needed it closer to the options menu we showed with the transparency
> stuff etc and size of fonts etc"

Second pass over the Options rebuild below, with the same two screenshots side by side.
The first pass copied the row *vocabulary* and not the *page*. Measured off the client's
Controls page this time:

| | was | now |
|---|---|---|
| Row label font | GameFontHighlightSmall, 10pt | GameFontHighlight, 12pt |
| Section heading | GameFontNormalSmall | GameFontNormalLarge, like "Controls" / "Mouse" |
| Checkbox | left edge, label after it | label left, box in the control column |
| Slider | label line + full-width track below, 42px | one row, track in the column, 26px |
| Control column | none — boxes left, selectors right | one, 174px in from every row's right edge |
| Background | fill 0.94 + stone 0.90 ≈ 99% opaque | fill 0.72 + stone 0.45 ≈ 85%, see-through |
| Width / panel height | 330 / 739 | 360 / 759 |

The column is the thing. Nine controls - four checkboxes and five selectors - now all
begin at the same x, which is most of why a page of unrelated settings reads as one
list rather than as a pile. A spec asserts it by collecting that x from all nine and
failing if there is more than one distinct value, so a tenth control added in the wrong
place cannot pass. Sound and Thunder stopped sharing a row, because a box that lives in
the right-hand column cannot share one: there is only one column.

Single-row sliders were not only fidelity. Seven sliders at 42px each was 112px of
window, and the full set of rows was 871px tall - taller than UIParent is on a 1080p
screen at the default scale, so the window would have been clamped and unusable. One row
each brings the whole panel to 759, which is 20px more than before at 2pt bigger type.

**Two fade lengths, which is the "didnt change quick enough".** Everything faded over
0.7s. That is right for walking under an awning and wrong for a button: most of a second
of nothing happening after a click reads as a click that missed. `FADE_SWITCH` is 0.12s
and applies whenever `db.enabled` changed since the last `Refresh` — which is the switch,
the checkbox and `/comfy stop`, and is not the doorway. `FADE_WALK` stays 0.7s and is
only restored once the previous fade has landed, so the indoor poll (one `Refresh` every
0.3s) cannot slow a switch down halfway through. The spec checks both halves in one test,
each the other's positive control.

The `golden_draw.txt` diff is one row, `### switched off`: the overlay's `OnUpdate`
returns early once `fade` hits 0, so it now stops advancing the gust phase 0.58s sooner
and the frozen gloom and scroll offsets differ in the third decimal. `overlay.shown` and
`overlay.alpha` are unchanged. Nothing drawn moved.

Also fixed: the status line read "Everything off. Nothing here is to..." on screen. It
had one fixed width, sized to leave room for the Turn It All Off button — and that button
is hidden in exactly the state that produces the longest sentence the window ever shows.
Two widths now, picked in `Refresh` beside the Show/Hide that causes it.

`wowmock.lua`'s `SetPoint` records `relPoint`, which it did not before. The column specs
need it: an offset from a row's RIGHT edge survives `Relayout` setting the width and an
offset from the left does not, and that is the difference the spec is asserting.

`tools/preview_panel.py` is stale in another way again — it knows nothing about the
control column, the single-row sliders or the checkbox being on the right.

## 2026-10-19 — the window is the client's Options window now

> "we did reload, now what, im confused, can u pleae fix the ui, the weird tellow
> is offputting.. why cant we make it like their options menu"

With a screenshot of the client's own Options > Controls page beside ours. The gold
wash below was the right reading of the wrong problem. **A row of four pills has to
shout which one is live, and the client's Options window never has that problem,
because it shows one value at a time.**

| Was | Is |
|---|---|
| 4 intensity pills, 4 time pills, 2 weather pills | one `Select` row each: `Label  ◀ [ Value ] ▶` |
| cycling pills for Indoors and Channel | the same `Select` row |
| checkbox drawn inside a `UIPanelButton` face | box and word on the panel, no face |
| icons on Thunder and Gusts | gone; the Weather well keeps the rain/snow pair |
| gold wash + gold label on the chosen pill | nothing; there is one value on the row |
| gold slider number when off default | white when off default, grey when on it |

- `Select` is the row the client uses for Loot Key. Arrows are the spellbook page
  arrows (130866 / 130869) rather than `UI-SquareButton-Up` (796424): the pair has
  been in the game since 2004 and the square button has not, which on a 1.60-branch
  client is the safer bet. `HasArt` falls back to `<` and `>`.
- Five pill grids gone. Window height is unchanged, but every group is now the same
  shape, which was the other half of the ask.
- **A spec now fails if any control in the window is gold**, with the Weather heading
  as its positive control. Gold is for headings, the title and the status line, the
  way the client uses it. Mutation-checked by putting the gold slider number back.
- 253 green. `GetStringWidth` was added to the manifest and verified present in
  `WowB.exe`.
- `tools/preview_panel.py` is now stale in one more way: it knows nothing about
  `Select`.

## 2026-10-19 — you could not tell what was on, or what was selected

> "the button doesnt look right for zoom response and i cant tell if its on or off..
> cant we maybe make things easier to understand wahts selected the text colour is
> very difficult"

Both halves were the same mistake: the window said on/off and selected/unselected with
signals too small to read on a dark button at 97px.

| Control | Said it with | Says it with now |
|---|---|---|
| Toggle, no icon | a 7px blue lamp | the client's own checkbox, ticked |
| Toggle, with icon | desaturating a 14px icon, lamp hidden | the tick, **and** the icon greys |
| Grouped pill | `SetButtonState("PUSHED")`, a 2px bevel | a gold ADD wash over the whole button |
| Any label | white vs `DIM` 0.62 grey | gold vs `DIM` 0.62 grey |

- `UI-CheckBox-Up` (130755) and `UI-CheckBox-Check` (130751) are referenced, not
  shipped, like every other piece of Blizzard art here. Both were confirmed in the
  listfile before being used.
- Asked through `HasArt`, because a missing box would leave a label indented past
  nothing and a toggle saying nothing at all. That is the one case the rule exists
  for. The 7px lamp stays as the fallback and `artPaths = {}` still exercises it.
- The selected state is a colour fill at `ADD`, not `UI-Panel-Button-Highlight`. The
  highlight file is a three-slice sheet and would distort stretched across a pill; a
  fill needs no `HasArt` and works on the flat-pill fallback too, which has no bevel
  to shift in the first place.
- The icon no longer carries the state alone. It used to hide the lamp to avoid
  saying it twice; the trouble was that a desaturated 14px icon and a lit one are
  nearly the same picture, so Thunder had no readable state at all.
- Four new specs, each mutation-checked: no glow, white-instead-of-gold, and a tick
  that never hides all fail the suite, each to the spec written for it. 253 green.

## 2026-10-19 — sweeps and golden files, so the client stops being the test rig

> "well can tu do more testing, we dont want to have to keep manually testinge tc"

The Darkness ceiling was green in 234 specs. Not one of them was wrong; they were
all the same shape — pick a setting, pick a value, assert the number — and that shape
cannot see a hole in the part of the surface nobody picked. **250 specs, all green.**

Two new instruments, both in `test/spec_sweep.lua`:

| Instrument | Catches |
|---|---|
| `golden_draw.txt` / `golden_motion.txt` | Any change to a drawn number, as a reviewable diff. 34 settings blocks and 11 motion blocks |
| Slider properties | The bottom is off; the top of an **absolute** slider means the same thing at every intensity. Each slider declares its kind or the suite fails |
| Range invariants over the matrix | 96 configurations × every colour, alpha and saved setting, after time has passed |
| Every command × 25 bad arguments | Nothing raises, and the addon still rains afterwards |
| Seeded 400-step random walk | Order-dependent bugs |
| Help coverage | A command the help never names |

**The sweeps found three real bugs on their first run:**

1. **`/comfy time 1e400` put a nan in `timeFixed`.** `tonumber("1e400")` is `inf`, not
   nil; `inf % 24` is nan; nan survives a min-then-max clamp untouched because every
   comparison against it is false. It then saves to disk and grades the light to nothing
   on every login after that. Fixed with `Num()`, which every number typed, pasted or
   read off disk now goes through. Found by the random walk, which nobody would have
   typed by hand.
2. **`timeOffset` was never clamped by the parser** — only on load, so a reload silently
   fixed it and the live session stayed wrong. Now clamped to ±23 where it is set.
3. **Seven commands were in the dispatcher and nowhere in the help**: `cycle`,
   `suppress`, `zoom`, `minimap`, `about`, `gust`, `volume`, plus `/comfy ui` itself —
   the settings window had no help line at all. All added.

The duplicate-block check earns its keep: four matrix rows in the first draft drew
identical frames (`rain, light` and friends, typed without their commands), and `time
+9` turned out to land on exactly the same light as `time 21` because the mock's realm
clock is noon.

`lua run.lua --update` rewrites the goldens. **Read the diff**; an updated golden with
an unread diff launders a regression into the record as intentional.

## 2026-10-19 — the Darkness slider could not reach full dark

> "maybe im wrong but i thought we could get it darker before"

He was right, and the reason was the slider, not the gloom. `GloomAmount` used to be
`p.gloom * db.gloom`, so the slider's maximum of 2 landed wherever twice the preset
happened to sit. His live SavedVariables had `gloom = 2` at `intensity = "normal"`, which
is `0.38 * 2 = 0.76` against an available 1.0. **The control looked like it had travel
left and did not**, and how much it had left changed with the intensity.

| Intensity (rain) | Preset | Old max (x2) | New max |
|---|---|---|---|
| light | 0.18 | 0.36 | 1.00 |
| normal | 0.38 | 0.76 | 1.00 |
| heavy | 0.75 | 1.00 | 1.00 |
| monsoon | 0.95 | 1.00 (clamped from 1.9) | 1.00 |

Only heavy and monsoon ever reached the clamp, which is why this read as "it used to be
darker" — it was, at the intensities he happened to be using when it was tuned.

Below 1 the slider still scales the preset and 0 is still a true no-op. Above 1 it now
closes the remaining gap to full instead of multiplying, so the right-hand end means "as
dark as this addon goes" in every weather and the middle still means the measured preset
curve from the 2026-10-15 screenshot sweep. Monotone across the join; three new specs,
mutation-checked (multiply-only and no-lower-branch both die).

Two other things were suppressing his darkness and neither is a bug: `timeMode = "off"`
turns off the second, independent darkening layer (the `tod` fullscreen MOD curtain), and
`scale = 0` means no rain is being drawn at all.

## 2026-10-19 (last) — two checks that need no client

The beta client is withdrawn **21 October** and the next one lands **4 November**, which
is also the CurseForge launch date. For those two weeks there is no way to log in and
find out whether an API we call exists, and `Unknown frame type 'ModelSceneFrame'`
already cost one wasted probe round. Both of these answer that question without the game.

**1. `tools/api_audit.py` + `test/api-manifest.txt`.** Pulls every global, `C_` member
and widget method the addon calls out of the Lua (comments and string literals stripped
first, so it audits the code and not the prose), looks each up in the strings of
`WowB.exe`, and writes the manifest. Result on build 1.60.1.70425:

```
controls: 5 found, 4 correctly absent
102 verified present, 6 client-Lua (unverifiable here), 0 MISSING
```

Three things about the method are worth keeping:

- **It runs its own positive and negative controls every time** and refuses to write a
  manifest if any fail. A zero from a broken scan reads identically to a clean result.
- **A name appears in the binary in two shapes.** Some are a bare line (`Hide`), some
  only ever inside a usage string (`Usage: local x, y = self:GetCenter()`). An
  exact-line matcher reports `GetCenter`, `GetPoint`, `NumPoints` and `GetRect` as
  absent, which they are not. Whole-line OR name-immediately-before-`(`.
- **FrameXML is not in the executable.** `ReloadUI`, `SlashCmdList`, `UISpecialFrames`,
  `CreateColor`, `Enum`, `SetBackdrop` and `Settings.Register*` live in the data
  archives. Their absence from the strings is not evidence, and the manifest marks them
  `LUA` rather than `MISSING`. It is also exactly why every call to them is `pcall`'d
  with a hand-drawn fallback behind it.

`--check` needs no binary at all: it compares today's source against the committed
manifest and fails with a name attached when the addon starts calling something that was
never checked. Wired into CI as its own step. Verified by planting
`UIParent:SetSomeImaginaryThing(1)` in UI.lua, which produced
`1 client API used by the addon and NOT in the manifest: SetSomeImaginaryThing`, exit 1.

**2. The stray-globals audit in `test/harness.lua`.** The sandbox env's `__index` fires
only for a name the mock did *not* provide, which makes it a free audit of the gap
between the mock and the client. Anything landing there that is a real client API means
the tested path and the shipped path are different ones: the addon reads nil in every
spec and something else entirely in the game. `H.run` now checks the accumulated list
against `EXPECTED_UNMOCKED` and fails the suite on anything unexplained.

It found one real gap on its first run: **`SOUNDKIT`**. `(SOUNDKIT and
SOUNDKIT.IG_MAINMENU_OPEN) or 567` had always taken the fallback branch in every spec
and would always take the other branch in the client. Now modelled in `wowmock.lua`.
Verified by planting `ImaginaryBlizzardGlobal`, which produced `GLOBALS NOTHING MODELS:
ImaginaryBlizzardGlobal` and exit 1.

Suite: **182 passed, 0 failed**.

## 2026-10-19 (later still) — a visible off switch, per-section resets, sharing

From live play: *"we are asking for a UI way to make it clear to turn things off etc,
also we need reset buttons for settings etc.. maybe even a way to share a profile or
setting.."* — the follow-on to the dark-screen trap below. The bug there was fixed; the
reason it was unfindable was not.

**1. The window now states what it is doing to the screen, before any control.** A line
at the top of the panel, refreshed every time anything changes:

| State | What it says |
|---|---|
| weather + light | `Drawing heavy rain, light held at 21:00.` |
| weather only | `Drawing heavy rain.` |
| **light only** | `Weather off, but light held at 21:00.` |
| neither | `Everything off. Nothing here is touching your screen.` |

The third row is the whole point. Time-of-day grading is the one effect with no weather
attached to it, so a player who switches the weather off and still has a dark world has
nothing to connect it to. Naming the held hour, in the window, is what turns an
unexplained dark screen into a setting with an off switch next to it.

**2. `/comfy stop`, and a `Turn It All Off` button on that same line.** Sets
`db.enabled = false` AND `db.timeMode = "off"` in one action. It is a **switch, not a
reset**: weather, intensity, sliders and the held hour are all kept for when it comes
back on. The button is hidden when nothing is on, so it is never a lie — if it is on
screen, pressing it changes something.

**3. Per-section resets.** `SECTIONS` in `ComfyRain.lua` is the single place the grouping
is written down (`look` / `sound` / `time`), and `Heading(parent, label, section)` hangs a
`Reset Look` / `Reset Sound` / `Reset Time` button off the right of each heading.
`/comfy reset <section>` does the same from chat; bare `/comfy reset` is still everything.
Rationale: "the sound is how I want it and the look is a mess" is the normal case, and one
button that takes the whole profile with it is one people learn not to press.

A spec walks every key in a fresh `db` against `SECTIONS` plus a hand-written furniture
allowlist, so **a new setting that belongs to no section fails the suite** rather than
shipping as a setting no Reset can reach.

**4. Sharing: `/comfy share` and `/comfy import <string>`.**
`ComfyRain1:enabled=1;weather=snow;intensity=blizzard;...` — plain text, not a base64
blob, and that is a choice. There is no base64 or deflate in the client's Lua, so an
encoded format means embedding LibDeflate for a string holding about twenty numbers; and
the plain version has a property the compressed one does not, which is that **a player can
read it before pasting it** and see it contains nothing but weather settings.

Nothing in import can run code. It is restricted to `PROFILE_KEYS`, coerces each value to
the type `DEFAULTS` declares, recovers enum values by name, and then runs the whole profile
through `SanitiseProfile`, which clamps every number and rejects every unknown enum. The
worst a hostile string can do is set rain to heavy. There is a spec that feeds it
`minimapAngle=0;migrated=0;scale=99;weather=goats` and asserts all four are refused.

Two case traps, both handled: the slash parser lowercases its input (so `import` is handed
the **untouched** argument, or `channel=Ambience` would silently reset their sound), and
Discord/forums mangle case anyway (so keys and enum values are matched case-insensitively
and the canonical spelling is recovered from `PROFILE_KEYS` / `ENUM`, never from the input).

**5. The share box.** There is no `SetClipboard` in the client's Lua, so an EditBox is the
only route a string has out of an addon. `ComfyRainShare` opens with the text already in it
and **already selected** — a box you have to drag across is not sharing. The same box reads
as well as writes: export arrives with text selected, import arrives empty and focused, and
Enter applies whatever is in it either way. If `UI.lua` failed to load, `/comfy share`
prints the string to chat instead; there is a spec for that path.

**Suite: 182 passing** (was 168). Ten mutations checked, all caught. The mock gained an
`EditBox` frame type with focus and selection recorded, and `ChatFontNormal` — an EditBox
with no font object draws no characters, so that line is not optional.

One latent weakness found and fixed while mutation-checking: `mock.printedMatching` returns
a **table**, so `ok(printedMatching(x))` is always true. Every other spec in the repo
already used `#... > 0`; the two new ones now do too.

## 2026-10-19 — renamed to Comfy Rain, and two audio bugs from live play

**Name, third and final: AlwaysRain -> Duskfall -> Comfy Rain.** Settled before any
public release exists, which is the only cheap moment to do it. The reasoning:
CurseForge search indexes the title, nobody searches "duskfall", and "rain" is the
word a player actually types. "Comfy" is the hook and the category the product is
really in (cozy ambience, not a combat tool). Snow is carried by the summary and the
tags rather than the title - "I Love Rain And Snow" covers both keywords but reads as
a novelty addon and is five words in an addon list column.

What moved: folder `ComfyRain/`, `ComfyRain.toc`, `## Title: Comfy Rain`,
SavedVariables `ComfyRainDB`, every frame and global, the test suite, both workflows,
`.pkgmeta`, `install.sh`, the README. Slash commands are now `/comfy` and `/rain`,
with `/comfyrain` and `/comfyui` opening the window. `/dusk` is gone.

Migration is a list, newest first: `DuskfallDB` then `AlwaysRainDB`, both guarded by
a type test and a pcall, both declared in `## OptionalDeps` so the old folder loads
first. Anyone who followed the first rename has both globals on disk and the stale
one must not win; there is a mutation-checked spec for exactly that.

**Workstation note:** the live `_classic_beta_` install has the old folders parked as
`_Duskfall_old` and `_DuskfallFlavour_old` so they no longer load, and the profile was
copied across by hand (`DuskfallDB = ` -> `ComfyRainDB = ` in the SavedVariables file),
so the in-client settings survived without needing the migration path.

### The hearth-to-Stormwind report, and what it actually was

Reported from live play: hearthed to Stormwind, no rain sound inside the inn, rain
visible inside, "not really outside". Two of the three are fixed; the third is a
question, not a bug, and needs the client to answer it.

| Defect | Cause | Fix |
|---|---|---|
| Indoor duck never applied | `BedVolume` bakes `IndoorFactor()` in at play time and `volumeOverride` cannot be changed on a running clip, but `Refresh` only relaunched on a missing ticker or a changed weather/intensity key | `bedIndoor` recorded in `StartBed`, cleared in `StopBed`, compared in `Refresh` |
| Silent after a loading screen | a loading screen stops every sound below the addon - no event, no error - while the Lua ticker survives, so `Refresh` concluded the bed was running | `StopBed()` on `PLAYER_ENTERING_WORLD`, so `Refresh` rebuilds |
| Rain "not really outside" | unresolved | `/comfy where` |

The existing indoor spec could not have caught the first one: it ran `/dusk heavy` with
the comment "forces a relaunch so a new gain is computed", and the relaunch was the
thing under test. A player walking through a door types nothing.

**`/comfy where`** prints `IsIndoors()`, `IsOutdoors()`, what `Sheltered()` concluded,
and the resulting `IndoorFactor()`. It exists because the visual half is not settleable
from source. `IsIndoors` and `IsOutdoors` are not complements, and the third state -
neither true - is a real awning in the open world and may also be an open street in a
city built as one big WMO. Those want opposite answers. Run it inside the inn and again
on the street; if `IsOutdoors()` is false on a Stormwind street then `Sheltered()`'s
"neither means indoors" default is wrong for cities and is a regression from 2026-10-18.

**Also:** `H.world()` now seeds the RNG. Lightning intervals are a log-normal with a
3.2x ceiling sampled against a 200-second assertion window, so two specs were failing
roughly 4% of runs each on correct code. A red CI run should mean something.

**Icon rebuilt.** The old one was a dusk gradient with rain streaks, which reads as
weather at 64px and as grey noise with a pink line at 20px, because streaks are
high-frequency detail and that is the first thing a downsample discards. Replaced with
a single outlined raindrop over the horizon glow, rendered at 4x and resampled once.
The streaks survive as background texture at a third of their old contrast.

159 specs, all green.

## 2026-10-19 — the dark-screen trap, found from live play

> "my screen is too dark and i cant reset it easily, like i want to turn off the changes
> it made but i cant"

**`/comfy off` did not turn off the light grading.** `tod` is the one drawing frame
parented to `WorldFrame` rather than to the overlay — `gloom`, `whiteout` and `flash` are
all overlay textures and were already going down with it. `UpdateTimeOfDay` only checked
`db.timeMode` and `cinematic`, so switching the addon off hid the rain and left a
fullscreen MOD texture holding the light at whatever hour was set.

The saved profile had `timeMode = "fixed"`, `timeFixed = 21`, `timeStrength = 1` and
`gloom = 2`, so the world was being held at 9pm with no rain on screen to explain it.
The escape hatch existed (`/comfy time off`) and was unguessable from a dark screen.

| | Before | After |
|---|---|---|
| `/comfy off` | rain gone, light still graded | everything down |
| Cause discoverable in game | no | `off`/`on` print what the light did |

Fixed at the top of `UpdateTimeOfDay` with an `db.enabled` check, plus a printed line on
`on`/`off` naming the hour, silent when the grading is already off. Both
mutation-checked. **An addon that cannot be switched all the way off is a trap** — worth
re-auditing any future frame that is not a child of `overlay`.

## 2026-10-19 (later) — zoom response, the barbershop, and 3D probe round two

Three things, all from live play on the beta client. **166 specs, all green**, every new
spec mutation-checked.

### 1. Camera zoom now changes the weather

Asked: "if we zoom in or out shouldn't it change how rain/snow looks?" It should, and
`GetCameraZoom()` is the **only** part of the world camera an addon can read — there is
no pitch and no yaw (see the binary table below). So this is the single genuine 3D cue
available to a 2D overlay, and it was not being used.

| Camera distance | What the field does |
|---|---|
| 0 yd (first person) | ~0.64x sheet density: fewer, larger drops, +20% fall speed |
| 9.75 yd (`ZOOM_PIVOT`) | exactly the tuned preset, unchanged |
| 15 yd (fully out) | ~1.19x density: finer, denser, same speed |

Carried on tiling, not on alpha, which is the opposite of how the gust does it. The note
at `LAYERS` says changing `tilesY` mid-flight reads as the camera zooming; that is an
artefact when nothing is zooming and the entire point when something is. Smoothed at
`elapsed * 5` because mouse-wheel zoom arrives in discrete steps.

`db.zoom`, default on, `/comfy zoom on|off`, and a **Zoom Response** toggle in the window.
The mock's `cameraZoom` is parked at 9.75 so every other spec measures a neutral field.

### 2. "Dim" indoors no longer draws anything

Reported from the Stormwind barbershop, and from the Stormwind inn before that. `dim`
used to mean a 25% wash of rain still drawn under a solid roof, and it reads as the addon
not noticing the ceiling rather than as weather outside. The two halves are now separate
numbers — `IndoorFactor("hear")` vs `IndoorFactor()`:

| | Old `dim` | New `dim` |
|---|---|---|
| Seen indoors | 0.25 | **0.0** |
| Heard indoors | 0.25 | **0.35** |

Which is also what Blizzard's own weather does. `off` and `on` are unchanged. A new
`ShouldDraw()` routes it through `fadeTarget`, so a doorway is a 0.7s fade and the
overlay then **hides**, costing no `OnUpdate` at all inside — asserted directly, because
asserting alpha alone passed either way.

**`db.where`, a passive doorway log.** `/comfy where` asks him to type a command at the
exact moment he is busy looking at the thing, and both reports came from memory
afterwards. Every committed indoor/outdoor transition now appends `{zone, subzone,
IsIndoors, IsOutdoors, Sheltered, mode}` to SavedVariables, capped at 300. He plays; the
file gets read. This is the instrument that will finally say what Stormwind's streets
report.

### 3. `/comfy probe 3d`, round two

First run returned `stage1=nothing stage2=nothing` and **proved nothing**:

- `CreateFrame(): Unknown frame type 'ModelSceneFrame'`. The C++ class is in the binary
  and `C_ModelInfo` still takes one as an argument, but **no Lua constructor is bound**.
  That stage was never a measurement. Dropped.
- `Model:SetCameraDistance(): Not using a custom camera` raised, and because the whole
  setup sat inside ONE `pcall`, `SetPosition` and `SetAnimation` never ran. An M2 whose
  animation was never started has emitters that were never told to emit, so "I saw
  nothing" is what a correct API and a broken setup both look like.
- **No positive control.** "Nothing rendered" is only evidence once something is known to
  render on the same surface.

Round two is three stages of six seconds, each call in its own `pcall`, and the first two
exist to make the third readable:

| Stage | Surface | Question |
|---|---|---|
| A | `PlayerModel` + `SetUnit("player")`, fullscreen | does ANY 3D draw over the world, and is the empty part transparent? |
| B | `Model` + LoginFX `165433` | do particle emitters run in a UI model frame at all? |
| C | `Model` + weather `166249` | the actual question |

`/comfy probe saw <A> <B> <C>`, each word `nothing`, `black` or `yes`. **The verdict table
is in the code, written before the answer exists:** any `black` → `no`, opaque surface.
`A ~= yes` → `unknown`, the control did not render so nothing else is evidence. `C yes` →
`yes`. `B yes, C nothing` → `partial`, wrong M2, try another. Otherwise `no`, geometry
renders and emitters do not. The ceiling if it comes back `yes` is unchanged from below:
no depth test, no readable pitch.

Each stage now also records whether its setup ran **clean**, and a spec asserts that word.
`fails()` originally walked its varargs with `ipairs` on a packed table, which stops at
the first `nil` — one successful call early in the list would have hidden every failure
after it and reported "clean" on a half-built frame. Fixed to `select("#", ...)`.

## 2026-10-19 — skybox and 3D rain, checked properly this time

Asked again: can we do a skybox, or 3D rain like Blizzard's? The previous answer was
"three research reports said no, do not re-litigate", which is an appeal to authority and
not evidence. Re-done against the binary directly, `WowB.exe` build `1.60.1.70425`,
934,670 extracted strings. **Positive controls:** `GetUnitSpeed` = 2 hits,
`PlaySoundWithOptions` = 2, `SetModel` = 24, `GetModelFileID` = 3.

| Candidate route | Result | Evidence |
|---|---|---|
| A skybox setter | **absent** | `SetSkyboxModel` 0, `C_Skybox` 0. `LightSkybox` appears only as a DB2 record class (`WowClientDB2<LightSkyboxRec_C>`), which is client data, not an API |
| World fog / light / gamma | **absent** | `SetWorldFogColor` 0, `SetWorldLight` 0, `SetGamma` 0 |
| `SetFogColor` / `SetLight` / `SetFogNear` / `SetFogFar` | **Model-widget methods** | each 1 hit, and each sits beside its own usage string of the form `Usage: local r, g, b, a = self:GetFogColor()`. The `self:` is the proof |
| `ApplyScreenEffect` / `ClearScreenEffect` | **not addon-callable** | both sit in ONE contiguous block with `ApplyWeather`, `RemoveWeather`, `ApplyTimeOfDay`, `SetDetailDoodadsOverride`, `ImportTimelineActor`, `IsTimelineEditing`, `EvalWorldStateExpression`, `LoadPath`, `GetHousingHouseMatrix`, and `ScriptPackageLoader::ScriptText`. That is the server-driven scene-script binding table |
| World camera orientation | **not readable** | `GetCameraPitch` 0, `GetCameraYaw` 0. `GetCameraZoom` is a global and sits with `CameraZoomIn`, `SaveView`, `SetView`, `MoveView*`, so distance only |
| `GetCameraPosition` / `GetCameraFacing` / `GetCameraRoll` | **a false lead, resolved** | they exist, but their usage strings are `self:GetCameraPosition()`. They read a *Model frame's own* camera, not the world's |
| Depth test control | **absent** | `SetDepthTest` 0, `SetUseDepthBuffer` 0. So nothing an addon draws can be occluded by terrain |

**What a Model frame actually has**, all confirmed present at 1 hit each with usage
strings: `SetModelScale`, `SetCamera`, `SetCameraPosition`, `SetCameraTarget`,
`SetPosition`, `SetFacing`, `SetPitch`, `SetRoll`, `SetTransform`, `SetViewTranslation`,
`SetViewInsets`, `SetParticlesEnabled`, `SetAnimation`, `SetSpellVisualKit`,
`SetDrawLayerEnabled`, `SetPaused`. `ModelSceneFrame` exists as a **C++ class**
(`.?AVModelSceneFrame@@`, `.?AVModelSceneFrameActor@@`, `CreateActor`, and
`C_ModelInfo.AddActiveModelSceneActor` takes one) but is **not a creatable Lua frame
type** — `CreateFrame("ModelSceneFrame")` raised "Unknown frame type" on 1.60.1.70425,
tested 2026-10-19. A class in the binary is not a bound constructor.

### The one thing the binary cannot answer

A Model frame is the only 3D surface an addon can create. Whether a *fullscreen* one
drawn over `WorldFrame` is transparent, and whether the M2's particle emitters emit
inside it, is a question about rasterisation and nothing in the API reports it.

`/comfy probe 3d` answers it. **Superseded by the three-stage version — see the later
section above.** The two-stage original ran 2026-10-19 and returned nothing in both
stages, which proved nothing: one stage used a frame type that cannot be created, the
other aborted its setup before starting the model's animation, and there was no positive
control.

**Interpreting the result in advance, so the answer is not rationalised after the fact:**

- `black` in any stage — the surface is opaque, 3D over the world is dead, done.
- `nothing` everywhere with the control rendering — emitters do not run in a UI model
  frame. Dead.
- particles in C — **it reopens**, but it is still not Blizzard's rain. There is no
  depth test, so terrain and buildings will never occlude it, and there is no readable
  world camera pitch, so the volume cannot track the view when the player looks up or
  down. The honest ceiling is "3D-looking particles with correct internal parallax,
  floating in front of everything", which is better than two flat sheets for depth and
  worse for anything near the camera. Worth a day, not a week, and not before launch.

## The finding that shaped it

Investigated client `WowB.exe`, build **1.60.1.70338** (`_classic_beta_`, portal `test`).
There is no supported way to force weather:

| Candidate | What it actually is |
|---|---|
| `C_Weather.GetCurrentWeather()` | the only Lua weather API — read-only, no setter |
| `ApplyWeather` / `RemoveWeather` | methods on the server-driven *scene script* object (next to `ApplyTimeOfDay`, `ApplyScreenEffect`), not addon-callable |
| `AllWeather` / `WeatherRain` / `WeatherSnow` / `WeatherSand` | values of the **transmog situation** enum ("wear this outfit when raining"), not setters |
| `weatherDensity`, `RAIDweatherDensity` | graphics CVars (0–3) controlling density of weather the server already sent |
| a `weather` console command | does not exist in this build — grepped every string |

Weather arrives from the server as `WEATHER_CHANGED`. The only way to force it client-side
is patching memory, which is bannable. Not doing that.

**Also found:** `weatherDensity` was `"0"` in both `_classic_beta_` and `_retail_` Config.wtf,
so real in-game weather was not being rendered at all. And `Sound_MasterVolume "0.10000000149012"`,
`Sound_MusicVolume "0"` in beta.

## Licensing: reference, never redistribute

Blizzard's [UI AddOn Development Policy](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534)
says *"it is illegal to distribute copyrighted materials, in this case in-game music and audio
files, without authorization."* The line that matters here:

- **Referencing a FileDataID at runtime is fine.** The file never leaves the player's own
  install. All the audio and the mist texture work this way, and nothing is shipped for them.
- **Shipping a file built from their art is not.** An earlier version composited Blizzard's
  `RainDrop01` sprite into the rain sheets, which would have redistributed a derivative of their
  texture. Replaced: `make_rain_tga.py` now rasterises every drop from an optical model, so the
  sheets contain no Blizzard pixels and the cached `.blp` is gone from the repo.

So **everything shipped is generated by this repo's own scripts**, and everything of Blizzard's is
referenced by number. `ls` of the installed folder should only ever show `.lua`, `.toc`, our
`.tga` sheets and our `.ogg` fallbacks.

### Interface art borrowed by path — DONE 2026-10-19

Same rule one layer up. Asked: can the window look more like the game's own? Yes. None of
the policy's seven provisions touches *using* the interface the client ships; the templates
exist to be inherited, and the art is read out of the player's own install at draw time.
Shipping a `.blp` (or a converted `.png`) of it would be redistribution and CurseForge
rejects it. `tools/api_surface.py` is blind to all of this — templates and art live in CASC,
not in `WowB.exe` — so **`GetFileIDFromPath` is the per-path existence test** and every
template is `pcall`-probed once and cached. Where a missing file would only look plain the
Blizzard texture is laid **over** something we already drew and no check is needed; only the
slider thumb and the icons, where a miss leaves nothing visible, are asked about.

Borrowed: `UI-DialogBox-Background-Dark` (tiled, over our fill), `UIPanelButtonTemplate`,
`UI-SliderBar-Background`/`-Border`/`-Button-Horizontal`, `UIPanelCloseButton`.

The three weather buttons carry icons, picked by rendering candidates **at 14px** rather
than reading their names at 64px:

| Button | Icon | Why |
|---|---|---|
| Rain | `Spell_Frost_IceStorm` | the shards lose their detail and leave slanted streaks |
| Snow | `Spell_Frost_FrostShock` | holds a bold snowflake at 14px |
| Thunder | `Spell_Lightning_LightningBolt01` | still a bolt at 14px |
| Gusts | `Spell_Frost_ArcticWinds` | the snow weather's version of the same slot |

**No icon anywhere in the game depicts rain.** The whole 2,274,746-row community listfile
was searched, not just the classic range, so Rain borrows a shape rather than a subject and
that is deliberate. `Spell_Frost_ChillingBlast` is the better picture at full size and was
the first choice; at 14px it dissolves into a white diagonal slash indistinguishable from
the rain icon beside it, and telling rain from snow is the one job that row has. A toggle
carrying an icon says on/off by desaturating it, which is the client's idiom, and its lamp
hides rather than saying the same thing twice.

### Tooltips, and why Channel stays — DONE 2026-10-19

Asked: do we need a WoW-item-style hover tooltip, and do we need the Channel button?

**Tooltips were already that.** `Teach()` draws into `GameTooltip`, which is the same frame
the game draws item tooltips into, so the border, fonts and anchoring are the player's own.
Two real gaps closed: the **Hour** slider had no tooltip at all (one row standing in for two
settings, so its title, note and command are now set by `Refresh`), and notes did not wrap —
`GameTooltip` sizes to its longest line, so a two-sentence note was a tooltip wider than the
panel. A sweep spec now walks every visible button and slider under the panel and fails on
any that says nothing, which is the guard a hand-written list of `Teach` calls cannot be.

**Channel stays, and now earns it.** The addon can play into any of the game's five volume
sliders but cannot make a sound on one the player has pulled to zero, and Ambience at zero
is common — the beta's own config had Master at 0.1 and Music at 0. Before this the panel
showed Sound: On, Volume up, and no sound, with nothing on screen to explain it. `Refresh`
now reads the CVars and the button says `Channel: Ambience  (muted)`, with a red tooltip
line; clicking it is also the fix. Covers the master switch (`Sound_EnableAllSound`), the
master slider and the per-channel pair. **Cannot-tell is not muted** — a name that moves in
a later flavour must not put a red warning on a panel whose sound is fine — and it stays
quiet while `sound` is off, because the panel already says that. All nine CVar names were
checked against `WowB.exe` 1.60.1.70425, with an invented name as the negative control.

### Sharing a profile: caption, the way in, the way back — DONE 2026-10-19

Three things, asked together.

**The caption was not cut off, it was wrapping off the bottom.** `ComfyRainShare` was a
fixed 104px with the caption at `-32` and the text well at `-48` — 16px, one line. Anything
longer was drawn underneath the well and read as a sentence stopping mid-word. The well now
hangs off the caption's `BOTTOMLEFT` and `ShowShare` sizes the frame from
`note:GetStringHeight()`, so the caption can be as long as it needs to be. That is what
makes the rest possible.

**Nobody was told how to paste one.** `/comfy import` with no argument already opened the
box empty; it was a command nobody had been given. The box now has a **Paste One** button
(hidden when `/comfy about` borrows the frame for the project URL), and both captions spell
out the round trip.

**Import is undoable, and that was the right answer to "without overwriting".** A preview
dialog listing twenty values is the wrong shape for a 330px window, and "merge without
changing anything" is a contradiction — the profile *is* the settings. What stops someone
trying a friend's profile is expecting to lose their own, so the import takes
`ExportProfile()` first and `/comfy undo` puts it back. In `db.undo`, so it survives a
reload ("import, /reload to be sure, change my mind" is the obvious way to use it), on the
FURNITURE list in the coverage spec, armed only when the import actually landed, and
cleared on use — one step back, not a history, and it says so when it is spent.

## Blizzard assets used, by FileDataID

Addons can pass a numeric FileDataID to `SetTexture` and `PlaySoundFile`, so the client's own
files are reachable with nothing extracted and nothing shipped. **A FileDataID needs no client
restart** — only new files on disk do. Durations below were measured from the real files
(pulled via `https://wago.tools/api/casc/<fdid>?download`) and must stay in sync with the
`bed` entries in the Lua's `WEATHER` table, because the loop ticker is driven by them.

| Asset | FileDataID | Measured |
|---|---|---|
| RainLightLoop.ogg | 538983 | 20.0 s, mean -35.8 dB |
| RainMediumLoop.ogg | 538981 | 30.0 s, mean -30.5 dB |
| RainHeavyLoop.ogg | 538982 | 25.0 s, mean -20.8 dB |
| FX_TKIsle_MWThunderRumble ×10 | 838830, 838832, 838834, 839725, 839727, 839729, 839731, 839733, 839735, 839737 | 5.5–7.6 s |
| WeatherMistGrainy01.blp | 396498 | 256×256, the mist veil |
| SnowLight.ogg | 538985 | **29.951 s**, mean -33.1 dB |
| SnowMedium.ogg | 538989 | 50.0 s, mean -30.8 dB |
| SnowHeavy.ogg | 538984 | 40.0 s, mean -22.9 dB |
| AMB_FrostFire_Heavy_Wind_base_loop.OGG | 918050 | 110.713 s, mean -24.2 dB — the blizzard's wind |
| FX_WindGust_OneShot_01-07 | 982361, 982363, 982365, 982367, 982369, 982371, 982373 | 5–6 s |
| SNOWMIST01.BLP | 186229 | the snow analogue of the mist veil |

SnowLight is **29.951 s, not 30** — rounding it would gap the loop by 49 ms every 30 seconds.
The snow beds spread 10 dB light-to-heavy where the rain beds spread 16 dB; that is Blizzard's
own mix and it is left alone. Sandstorm (538988 / 538987 / 538986) exists on the same naming
scheme but has no art here, so `/dusk auto` declines it rather than half-applying it.

**Blizzard ships no tiling rain-curtain sheet** — only single particle sprites (`RainDrop01`,
186226), placed by a particle system an addon cannot reach, and a sprite cannot be tiled into a
curtain at runtime. Combined with the redistribution rule above, that is why the drops are
generated rather than borrowed. Also looked at and rejected on appearance: `UI_Worgen_Rain01`
(313250, faint horizontal streaks) and `worgen_RainEffects_01` (304844, a splash decal).

FileDataIDs came from `listfile/verified-listfile.csv` (community listfile, tag `202610111812`,
1,087,814 rows — not checked in, 71 MB).

## How the addon works

- A frame parented to **`WorldFrame`** (not `UIParent`) at strata `BACKGROUND`: draws above the
  3D scene, below every UI frame, and stays visible when the UI is hidden with Alt+Z.
- Two weathers, **rain and snow**, as one `WEATHER` table: each carries its own sheets, mist
  texture and tint, slant and sway, gloom tint, four beds, one-shot list, and whether it
  flashes. Everything else in the addon reads through it, so a third weather is a table entry.
- Three scrolling layers — Blizzard's mist texture, then far and near sheets — using
  `SetTexture(..., "REPEAT", "REPEAT")` and `SetTexCoord` offsets > 1 to tile. `tilesX` is derived
  from screen aspect each frame so drops stay the right shape at 2125x1080 and at any other size.
- An additive white flash texture for lightning, with thunder trailing 0.6–3.2 s behind it.
  Snow does not flash: the same scheduler fires a wind gust instead, because a snowstorm has
  no lightning in it.
- **Snow is not slow rain.** Rain falls at ~9 m/s and smears into streaks; snow falls at ~1,
  tumbles, and drifts sideways on any breeze, so the snow sheets are soft blobs and the scroll
  carries a sway term (a sine on the slant, ~18 s period) that rain's is zero for.
- **Blizzard** is the one preset with a whiteout: an **ADD** quad, because MOD can only darken
  and a whiteout brightens. Capped at 0.22 even at maximum alpha, since an addon that hides a
  mob is an addon that gets uninstalled. It also swaps the near layer for a separate gale sheet
  (wind-driven snow is near-horizontal streaks, not the same sprite scrolled faster) and runs a
  **second audio loop** — the 110.7 s wind under the 40 s snow bed. Nothing else needs two.
- Audio: Blizzard's rain loop for the current intensity, relooped by
  `C_Timer.NewTicker(len - 0.12)` using that file's exact measured duration. Falls back to the
  bundled `rain.ogg` only if `PlaySoundFile` refuses the FileDataID, and says so in `/dusk status`.
- **Indoors:** `IsIndoors()` is polled every 0.3 s with a 0.9 s debounce (so an archway does not
  restart the audio), plus the `ZONE_CHANGED*` events. Going inside fades the overlay out over
  0.7 s and stops the bed; `/rain indoors on` opts back into raining inside.

### Asset generation
Assets are not checked in; they are deterministic output of the build scripts.
- `build/make_rain_tga.py` — 512×512 32-bit **uncompressed** TGA (WoW rejects RLE TGA), drops
  scattered so the sheet wraps in both axes. `SLANT_DEG = 7.5` here **must match** `SLANT` in
  `Duskfall.lua` as its tangent (0.1317). Each drop is rasterised from an optical model: a
  Gaussian across the width (the drop's own blur circle), an exponential falloff from the bright
  leading head up the tail, both ends windowed to zero so nothing terminates in a chopped edge,
  and the slant sheared in during rasterising so thin streaks are never resampled. Per-drop taper,
  curvature and an 8% chance of a brighter glint give variety a single sprite could not.
  Widths are absolute pixels, not a fraction of length — real rain stays hair-thin however long
  the streak is, and scaling width with length gives 30 px bars.
  **Retuned 2026-10-21** from far `260 @ 20-46px` / near `70 @ 80-190px` to far `700 @ 14-34px`
  / near `380 @ 16-40px`. Sheet pixels are not screen pixels: the Lua multiplies `tilesY` by the
  per-intensity `density`, which is inverted (monsoon 0.58), so at the Storm preset a near-sheet
  pixel covers **2.425** screen pixels. Measured off a real `/comfy stop` → `/comfy preset storm`
  capture pair in `_forever_`, the old art put the longest near streak at **546 px, 51% of frame
  height**, with only **53 streaks crossing the middle** of a 1920 px screen. Three independent
  checks agreed it was ~4× too long: on-screen size, layer isolation (the far layer was invisible,
  so there was no depth), and the scroll rate, which implies an **80 ms** camera exposure on the
  near layer against a film-standard 21 ms. Blend mode was left at `ADD`: a four-way ablation put
  the sheet art at ~10× the effect of the blend, and `LAYERS` is shared with snow, which is fine
  as it is (`density 1.00`, so no magnification).
- `build/make_snow_tga.py` — `snow-far.tga`, `snow-near.tga`, `snow-gale.tga`, same format and
  same no-Blizzard-art rule. Flakes are rasterised from a model: a Gaussian with a brighter core,
  plus a **weak** (0.07) randomly-phased six-fold modulation on the near layer only — enough to
  break the perfect circle, not enough to draw a snowflake icon. Placement is a **jittered grid**,
  not uniform random: at a few hundred flakes, uniform random leaves bald patches and clumps, and
  a 512 px sheet repeats any such blotch four or five times across the screen. Elongation comes
  from wind, not gravity, which is why only the gale sheet has it (5× at 78° off vertical).
  Measured coverage: far 7.9%, near 16.3%, gale 22.7%, against rain's 7.0% and 4.7%.
  **Retuned 2026-10-22**, same defect the rain sheets had. `sigma` is not the flake: visible
  diameter is about `3*sigma`, and the Lua then magnifies by `H/(tilesY*density*512)`, x1.71 at
  snow heavy. Snow's `density` is inverted too (light 1.20, normal 1.00, heavy 0.82, blizzard
  0.66), so **flakes grew as the snow got heavier** — heavy snow was 565 fat blobs up to 32 px
  across where light snow was 1210 small ones. Gale was worse: the longest blizzard streak was
  **205 px, 19% of frame height**, reading as scratches on glass. Now far `1500 @ 0.9-1.9`, near
  `800 @ 1.3-3.0`, gale `900 @ 0.9-1.9 elong 5.0` (was 900/210/300 at 1.1-2.3, 2.6-6.2,
  1.5-3.2 elong 7.0). Near flakes land at 7-20 px on screen across the whole ladder.
- `build/check_art.py` — tests the TGAs **on disk**, not the generators that wrote them, because
  the file is what the client loads and a generator that runs clean can still emit something WoW
  silently refuses to draw. Takes a directory, defaults to the installed `_forever_` addon, exits
  non-zero on failure, and runs in CI against the art the `assets` job has just generated.
  Seven checks: TGA format (power-of-two, 32-bit, **image type 2** — type 10 is RLE and draws
  nothing with no error), alpha saturation, flat RGB (colour comes from the Lua tint, so a
  gradient here fights it), the wrap seam, placement uniformity, largest on-screen element, and
  the icon's legibility at 20 px.
  Two of those are measured **against a control rather than an absolute**, because an absolute
  threshold would be arbitrary: the seam's wrap step is compared to the p99 of 200 random interior
  lines of the same sheet, and the 8×8 grid coverage spread is compared to the binomial spread
  random placement would give at that coverage.
  The on-screen check measures the largest element off the sheet's own alpha — longest unbroken
  **wrapping** run at `alpha > 0`, since the sheet tiles and an element split across the seam is
  one element on screen. Each axis is judged against its own screen dimension: a gale streak lies
  nearly flat and crosses the 1920 px width, not the 1080 px height. Ceiling is **12% of the
  frame**, calibrated, not picked — the sheets Reddit called bars measure 16.4% (rain near),
  14.8% (snow near) and 21.5% (gale); the retuned ones measure 7.0%, 5.7% and 8.9%.
  **Threshold matters here:** at `alpha > 2/255` or higher the measured length roughly halves and
  the check can no longer separate the old sheets from the new, because a streak's tail tapers to
  nothing and on an `ADD` layer over a dark sky the eye still sees it.
  Positive controls run 2026-10-22, all three fired: the pre-retune art gives 4 FAIL / 2 WARN
  (rain-near 16%, snow-near 15%, gale 22%, gale clumpy at 12.3× random), a deliberately RLE-saved
  sheet is caught as `image type 10`, and the shipping art gives 0 / 0.
- `build/make_rain_audio.py` — the fallback bed only. Noise is shaped in the frequency domain over
  exactly one loop length, so the result is periodic and the join is sample-exact; that removed
  the end fades v1 needed, which were what made two clips audibly swell over each other.

## Install

```
./install.sh                # _classic_beta_
./install.sh _forever_      # the stress test / launch client
./install.sh _retail_
```
A **full client restart** is required for a first install — WoW only scans `Interface/AddOns`
at launch. Later Lua edits need only `/reload`.

**Each flavour has its own `Interface/AddOns` and `WTF`.** Installing to `_classic_beta_` does
not put the addon in the stress test client. As of 2026-10-21 18:35 ComfyRain is installed in
BOTH `_classic_beta_` and `_forever_`; any Lua edit has to be pushed to each one you are testing
in. Interface number is the same (16001) for both, so there is no out-of-date prompt.

## The settings window

`/comfyrain` (or `/comfyui`, or `/comfy ui|config|options|settings`) opens it. `/comfy` on its
own still toggles the weather, because nobody types eight letters to flip a switch. It opens
itself **once, ever**, four seconds after a first install, and records `db.seenUI` so it never
does it again — the onboarding hole both consult models flagged.

Top to bottom: the state line and `Turn It All Off`, then **Weather** / **Sound** / **Time of
Day**, each heading carrying its own Reset, then a footer of `Commands` · `Share` · `Reset All`.

Four things about it are deliberate and should not be "simplified" later:

1. **It is a frame we draw ourselves, not a Blizzard Settings panel.** The Settings API is not
   known to work on this client: `AddSearchTags` already throws `ADDON_ACTION_FORBIDDEN` here,
   and Phase 1 item 7 (does a canvas category register at all on build 70338) is still open. The
   settings window is what a non-power-user needs most, so it cannot be the one part of the addon
   that depends on an API we have never seen work. It also uses **no template, no Backdrop and no
   UIDropDownMenu** — every pixel is `CreateFrame` / `CreateTexture` / `CreateFontString`, which
   the weather overlay has already proven on this client. The channel picker is a cycling button
   for that reason, and the checkboxes draw their own lamp.
2. **Every control issues a slash command** through `ComfyRainAPI.Command`, and none of them
   writes a setting directly. So the window can never do something the command line cannot, the
   two can never disagree, and the entire settings surface stays behind the slash parser's
   existing tests. `HandleSlash(input, "ui")` suppresses the chat status line; a typed command
   still reports.
3. **Every tooltip names the command it runs.** The window is not a replacement for the commands,
   it is how you learn them: drag the slider, read `/comfy alpha 0.75`, type it next time.
4. **The state line is not decoration.** It is the only thing in the window that answers "what
   is this doing to my screen" without reading a single widget, and it exists because a player
   could not find the one effect that had no weather attached to it.

There is no OK / Apply / Cancel. The weather is drawn live behind the window.

`UI.lua` is a third TOC file and is **not load-bearing**: every entry point is `pcall`ed, a world
without it falls back to printing the command list, and there is a spec for each.

## Commands

`/comfy` toggle · `/comfy rain|snow` · `/comfy light|normal|heavy` · `/comfy monsoon` ·
`/comfy blizzard` · `/comfy auto` · `/comfy alpha 0.75` · `/comfy speed 1.4` ·
`/comfy dim 0.5` · `/comfy gust 0.5` · `/comfy zoom on|off` ·
`/comfy indoors off|dim|on` · `/comfy sound on|off` · `/comfy thunder on|off` ·
`/comfy volume 0.5` · `/comfy channel Ambience|SFX|Master|Music|Dialog` ·
`/comfy time local|+9|21|off` · `/comfy time strength 0.7` · `/comfy where` ·
`/comfy density` · `/comfy status` · `/comfy probe` · `/comfy calib on|off|wipe`

**Off, reset and share:**

| Command | What it does |
|---|---|
| `/comfy off` | weather off; the light grading is left as it was |
| `/comfy stop` | **everything** off, weather and light, settings kept |
| `/comfy reset` | every setting back to defaults (keeps the calib log) |
| `/comfy reset look\|sound\|time` | one section only, nothing else moves |
| `/comfy share` | the profile string, in a box, already selected |
| `/comfy import <string>` | apply someone else's; bare `import` opens an empty box |

`/rain` is a permanent alias for `/comfy`. `/comfyrain` and `/comfyui` open the settings
window.

`monsoon` and `blizzard` each name a weather as well as an intensity, so they switch both:
nobody typing `/dusk blizzard` wants rain. Switching weather at the top of one scale lands at
the top of the other, and `db.intensity` is normalised on every change so a saved setting can
never name a preset the current weather does not have. `/dusk auto` is a one-shot match to
`C_Weather`, not a mode — there is no weather event to hang a mode on, and a ticker polling it
would cost more than it is worth.

### `/rain calib` — the session that expires on 21 October

`/rain calib on` raises the density CVars, registers `CONSOLE_MESSAGE` and
`WEATHER_CHANGED` (each through `pcall`, because an unknown event name throws on this
client and aborts the rest of the file with it), and from then on every real weather
change is shouted in chat and appended to `DuskfallDB.calib` with the zone, uiMapID,
game time, indoor flag, both CVars, the `C_Weather` reading and the parsed console line.

It is written to shout because real weather is server-driven and intermittent: it cannot
be summoned, so the only workable protocol is to raise the density, go and play, and be
told when it arrives. Turn `/chatlog` on as well — early Forever builds wrote
SavedVariables and never read them back, and a log in one place is not a log.

When it fires: screenshot, `/rain off`, screenshot the same frame again. Those pairs are
what every gloom and streak default should have been derived from.

## Prior art — what every other weather addon does

Surveyed 2026-10-12. Each was downloaded and the Lua read; **nothing was copied**, the
sources are listed so a reader can check the claims. Downloads live in `/tmp/wowaddons`
and are not part of this repo.

| Addon | Source | Size | What it actually does |
|---|---|---|---|
| [Dynamic Weather](https://www.curseforge.com/wow/addons/dynamic-weather-immersive-realistic-changing) | Scroll_Keeper, Public Domain, 20.7k dl, last touched 2021 (`## Interface: 40300`) | 1,895 Lua lines, 46 MB of TGA | 18 weather states, ~200 zones mapped to biomes, four seasonal biome tables keyed off the real calendar, a Mersenne Twister in Lua seeded from `GetServerTime()`, hourly forecast bar, flavour text per transition, Blizzard soundkit IDs per state, 14 lens droplets |
| [Dynamic Azeroth Weather](https://www.curseforge.com/wow/addons/dynamic-azeroth-weather) | ForgeDMC, 2026, 358 dl | 1,061 Lua lines over 7 files | FNV-1a hash of `zone .. hour bucket` → weighted choice, 4-hour forecast, per-zone climate weights, minimap button, options panel, thunder flash + fake screen shake |
| [RainingBlood](https://www.curseforge.com/wow/addons/rainingblood) | vggoecks, MIT, 2019 | **2 lines** | `SetCVar("weatherDensity", 3)` and `violencelevel 5` |
| [ImmersiveWeather](https://www.curseforge.com/wow/addons/immersiveweather) | Viinchesterr, 2025 | ~40 lines | A text label by the minimap. No visuals at all |
| [DayNight](https://www.curseforge.com/projects/95595/) | 2015, 136 dl | tiny | Drives the `gamma` CVar down at night. Darkens the UI too |
| [Weather](https://www.curseforge.com/wow/addons/weather) | keyboardturner, **All Rights Reserved**, 2,308 dl, 0.0.9 of 2026-08-17 (read 2026-10-12) | 18 Lua files, 49 MB | The only other addon in the survey that tints the screen. Indoor audio muffling, free-fall wind, skyriding wind by speed, a "Collector Almanac", a forecast icon, **`LibForecast`**, and a fullscreen `ScreenEffects` tint |

### What they have that we do not

1. **Deterministic weather with no addon comms.** Hash the zone name plus the current
   hour bucket of `GetServerTime()` and everyone running the addon sees the same sky
   without a single packet. Both of the serious addons landed on this independently.
2. **Per-zone climate weights.** Rain in Wetlands, sandstorm in Tanaris, snow in Dun
   Morogh. One table, and the addon stops being a rain addon.
3. **Seasons**, from the real calendar month.
4. **A forecast** — "heavy rain in two hours" — and flavour text on each transition.
   This is what makes it feel like a world rather than a filter.
5. **Blizzard weather soundkits by ID**, far beyond our two files. From Dynamic
   Weather's table: overcast 18414, light rain 111995, heavy rain 112759, thunder
   111998, blizzard 39789, high wind 39821, sandstorm 21436, snow flurry 4197.
6. **Lens droplets** — a handful of droplet sprites held on the camera.
7. **An options panel.** Both have one. We have slash commands only.

### What we already do better

- **Not one addon in the survey calls `SetBlendMode`** — grepped across all six, including
  every one of Weather's 18 Lua files. Our MOD-blend gloom quad is the only multiplicative
  darkening in the field. See "Weather tints, we multiply" below for why that is not a
  quibble.
- Dynamic Azeroth Weather parents its particles to `UIParent`, so its rain draws **over
  the action bars**. Ours is a `WorldFrame` child.
- Its "rain" is 200 white 2x20 rectangles moved in `OnUpdate`. Ours is a tiling sheet.
- Dynamic Weather ships 46 MB of uncompressed TGA; ours are two 512px sheets generated
  at install time.
- Nobody in the survey shifts time of day.

### The two-line finding

`weatherDensity` on this machine is **`0`** and `graphicsEnvironmentDetail` is **`1`**.
At those values the client will not draw Blizzard's real weather at all, which is why the
realm's own rain has never once been visible here. `/rain density on` raises both. That is
the whole of RainingBlood, and it is a bigger visual change than anything we have written.

### `C_Weather` exists and is readable

Verified in the 1.60.1.70338 binary at offset 81939440: a `C_Weather` namespace with
`GetCurrentWeather`, an `intensity` field, and `Enum.WeatherType` = `Rain`, `Snow`,
`Sandstorm`. It is **read-only** — there is no setter, so it still cannot force weather —
but it lets the addon know when the client is already drawing real rain instead of
doubling up on it. Surfaced in `/rain status`. Not yet confirmed in a running client.

### Weather tints, we multiply

Read 2026-10-12 from `Weather/ScreenEffects.lua` (231 lines). It builds one fullscreen
texture on a `WorldFrame` child at `BACKGROUND` strata, draw layer `BACKGROUND` sublevel
`-8`, and calls `SetColorTexture(r, g, b, a)` with `MAX_ALPHA = 0.30` — the source comment
reads *"any higher than this feels a bit too intense"*, which is a calibrated number from a
shipping author and worth having. There is **no `SetBlendMode` call**, so it is the default
`BLEND`: alpha compositing, not multiplication.

That is a different operation, not a weaker version of ours:

| | Alpha blend (`Weather`) | MOD (ours) |
|---|---|---|
| Maths | `scene·(1−a) + colour·a` | `scene × colour` |
| Black pixel | **lifted** off black | stays black |
| Physical analogue | translucent sheet in front of the lens | less light reaching the scene |

Their rain colour is `{0.20, 0.45, 0.85}`, a saturated blue. At alpha 0.30 a black pixel
becomes `{0.06, 0.135, 0.255}` and a white one `{0.76, 0.835, 0.955}`. The scene is washed
toward mid-blue from *both* ends and the black floor comes up — a colour cast. MOD leaves
black at black and scales everything else down, which is what a cloud layer actually does
to sunlight. Their snow colour `{0.90, 0.95, 1.00}` is near-white and **brightens** a dark
scene, which is right for a whiteout and wrong for gloom.

So the claim to make publicly is not "nothing else darkens the sky" — Weather does. It is
**nothing else darkens it multiplicatively**, which is checkable and true across all six.

### `CONSOLE_MESSAGE`: a second weather source, better than `C_Weather`

The best idea in the survey, and it was in none of the three reports. `Weather` does not
call `C_Weather` at all. Its bundled `LibForecast` registers the **`CONSOLE_MESSAGE`**
event and regex-parses the engine's own line:

```
Weather changed to <type> intensity <0.0-1.0> recID <id>
```

via `string.match(message, "changed to (%d+)")`, `"intensity ([%d.]+)"` and
`"recID (%d+)"`. The library's header notes console messages are always English, so there
is no localisation problem.

Three reasons this beats `C_Weather.GetCurrentWeather()` for us:

- **Raw numeric type, not a 3-value enum.** They carry a `Firestorm` type that
  `Enum.WeatherType` has no name for.
- **A `recordID`**, resolved through a 206-line table — the specific weather record, far
  more granular than Rain/Snow/Sandstorm.
- **It is old engine plumbing.** `C_Weather` is a 12.1.5 retail addition; we have only
  proven its *strings* are in the Forever binary, never that it answers at runtime.
  `CONSOLE_MESSAGE` long predates it.

Not yet tested on our client — the message text above is read from their Lua, not observed
in our console. `/etrace` plus a real storm settles it, and that is a calibration-session
task. Use it as the primary source with `C_Weather` as the cross-check, not the reverse.

## The three deep-research reports

Delivered 2026-10-12, all three reading `dr-prompt.md` v2. Their disagreements, resolved:

| Question | Verdict | How it was settled |
|---|---|---|
| Does `Weather` darken the screen? | **Yes.** Report 2 said audio-only and was wrong; report 3 was right | Read `ScreenEffects.lua:72` ourselves |
| Does anything else use MOD? | **No** | `grep -rn SetBlendMode` over all six addons, 0 hits |
| Beta window | Ends **21 Oct 2026**; launch 4 Nov 2026, 3pm PST | Two independent sources |
| TOC flavour suffix | **Unresolved.** R1 says `_Camelot.toc` and that `_Forever.toc` is "proven ignored"; R2 and R3 say comma-separated `## Interface:` plus `AllowLoadGameType` | Only R1 cited anything. Must be tested on the client |
| Packager version | **v2.6.1** | Unanimous, and v2.6.1 fixes a WoWI check in v2.6.0 |
| Collapse the MOD quads | **Yes**, exact and free | Unanimous |
| Determinism | Hash **uiMapID** + time bucket, FNV-1a, no `SendAddonMessage` | Unanimous |
| Schema before GUI? | **Yes.** R1 and R2 say schema first; R3 says GUI first and is outvoted | Binding sliders to hard-coded locals means rewiring every one later |
| Keep permanent rain? | **Yes.** Vary *intensity* so it never flatlines, never to zero | R2 argued for 20% clear spells; the addon was called AlwaysRain. **That half of the argument died with the name on 2026-10-14** - `Duskfall` does not promise permanence, so clear spells are now an open question rather than a contradiction. The default stays permanent until something says otherwise |

Only report 1 flagged the **SavedVariables bug** — early Forever builds wrote them and
never read them back. Reportedly fixed by build 69913, contested, and we are on 70338. A
settings GUI is worthless if settings evaporate, so probe it before building one:
`/run DuskfallDB.probe = time()` → `/reload` → `/dump DuskfallDB.probe`.

Other traps worth keeping, all from report 1: registering an unknown event **throws and
aborts the whole file**, so `pcall` the `WEATHER_CHANGED` registration; `select(4,
GetBuildInfo())` returns `16001`, so any `>= 100000` check takes the wrong branch; the
client stops reporting Lua errors after 100 in a session; and do not call
`initializer:AddSearchTags(...)`, which throws `ADDON_ACTION_FORBIDDEN` on Forever.

### The deadline that reorders everything

**Beta client access ends 21 October 2026.** Launch is 4 November. Every visual default in
this addon — gloom colour, streak alpha, sheet density, layer speeds — was guessed, because
`weatherDensity` was `0` on this machine and Blizzard's real rain has never once been
rendered here. Calibration is the **only** task on the roadmap that becomes impossible
after the 21st. It goes first, ahead of the schema, the GUI and everything else.

## What this can never match

Blizzard's rain is **3D particles in world space**. They have depth, they parallax
correctly as you move, buildings and terrain occlude them, and they splash. This is a flat
sheet in front of the camera. Two of the gaps are now papered over — a MOD-blend quad fakes
the lighting change, and yaw parallax sweeps the curtain when you turn — but occlusion and
splashes are not reachable from an addon at all, and the depth is faked with two layers
rather than real.

World lighting is the hard limit: `SetFogColor`, `SetLight` and `SetFogNear`/`SetFogFar`
exist in this client but are **Model-widget methods** (they sit beside `SetModel` and
`GetModelFileID` in the API table), so they apply to a model frame, not the world. There is
no world fog or ambient-light setter exposed to addons.

## How Blizzard keeps everyone's sky the same

Researched 2026-10-12 from [CMaNGOS](https://github.com/cmangos/mangos-classic) source. **Caveat:
that is a reverse-engineered reimplementation, not Blizzard's code.** It is good evidence of the
protocol's *shape*, because a server has to match it byte-for-byte or real clients break, and the
weather chance tables are read from Blizzard's own DBC files. It is not evidence of their
intentions, which are inferred below and labelled as such.

**Both systems are a seed, not a stream.** The server sends a tiny bit of state; the client
renders from it. Nothing about the sky is streamed continuously.

| | Day / night | Weather |
|---|---|---|
| Packet | `SMSG_LOGIN_SETTIMESPEED`, once at login (`SMSG_GAMETIME_UPDATE` re-syncs drift) | `SMSG_WEATHER` |
| Payload | realm wall-clock packed into bitfields, + a speed float | type, grade (0-1 float), **sound id**, smooth/instant flag |
| Scope | per player, but seeded from one realm clock | **per zone**, broadcast to everyone standing in it |
| Cadence | once; the client then runs its own clock | re-rolled every 10 min (`ChangeWeatherInterval`) |

- **Classic's day/night is exactly 1:1 with real time.** The speed float is `0.01666667`, which is
  1/60 game-minutes per real second — one game minute per real minute. So the in-game hour is
  simply the realm's wall-clock hour, which is the whole reason `/rain time local` is worth having.
- **Weather is rolled per zone from a seasonal table.** 30% no change, 30% better, 30% worse, 10%
  radical, with rain/snow/storm chances looked up per zone *and per season* (season computed from
  the real calendar date). Grade falls in three bands at 0.33 and 0.67 — which is exactly why there
  are three rain loops, and it matches the three FileDataIDs in the table above.
- **The packet carries the sound id**, so the server nominates which ambience the client plays.
  Using those same loops by FileDataID is doing what the client would have done anyway.
- **`m_isPermanentWeather` exists.** Permanent weather is a first-class server-side concept — it is
  how a zone rains 24/7. What this addon fakes is a thing Blizzard built, just never exposed to the
  client or to addons.
- **Inferred intent:** a seed costs almost nothing on a 2005 connection, and broadcasting weather
  per zone rather than per player means two people standing together always see the same sky. The
  shared world is the point.

**Why this addon does not touch any of it.** It sends no packets, registers no packet handlers,
and changes no client state. The realm still tells our client exactly what it tells everyone
else's, and the client still believes it. We paint over the finished frame afterwards, the same as
a monitor's colour profile would. Two players standing together still *are* in the same weather at
the same hour; only one of them is looking at it through a filter.

## Time of day ("Australian mode")

WoW's day/night runs on the **realm's** clock, so playing far from your realm means in-game
midnight at lunchtime. `/rain time local` grades the screen towards your own clock instead.

- `/rain time local` — match the machine's clock · `/rain time +9` / `-5` — shift by hours ·
  `/rain time 21` — hold one hour · `/rain time off` · `/rain time strength 0.7`
- Its own frame (`DuskfallTimeOfDay`, frame level 1, under the rain at level 5) so it works
  with the rain off. Wanting your realm's night to match your clock has nothing to do with rain.
- **Graded by the ratio between the wanted hour and the realm's hour, not by the wanted hour
  alone.** The world is already lit for the realm, so realm 22:00 wanting 22:00 must be a no-op;
  grading on the target alone would double-darken every night. Verified: no-shift returns exactly
  (1.00, 1.00, 1.00) with zero lift.
- **Day to night works; night to day barely does.** Darkening is a multiply and multiplies are
  free. Brightening needs ADD, which lifts the black level without restoring contrast, and the
  skybox keeps its stars and its absent sun regardless. The lift is capped at 0.13 so it never
  turns the screen to milk. An Australian on a US realm wanting their evening is the good
  direction; wanting daylight at realm-midnight is not, and that is a hard limit, not a tuning
  problem.
- Measured grades: realm 13:00 showing 22:00 → dim (0.34, 0.40, 0.66); realm noon showing 19:00
  → dim (1.00, 0.74, 0.55); realm 22:00 showing 13:00 → dim unchanged, lift 0.130.

## The product research: three reports, 2026-10-13

Three reports against `dr-prompt-product.md`. The one finding that mattered came from a
single report and was missed by the other two, so it was verified directly before being
believed.

### FAME exists, and it is not this product

[Forever Ambient Music Extended](https://www.curseforge.com/wow/addons/forever-ambient-music-extended-fame)
(kirillburton, project 1728351). Downloaded 0.2.0 and read all 2,731 lines on 2026-10-13.
133 downloads across two files, 0.1.0 on 6 October and 0.2.0 on **12 October** — one day
before this was written, so it is actively developed. Forever-only, game version 1.60.1.

It is a **zone-music track-pool expander**: 408 extra Blizzard tracks tagged by biome,
culture and mood, chosen by location, deliberately preserving Blizzard's own schedule,
silences and arrival fanfares. No UI. Data files are plain Lua and editable.

What it is not, verified by grep across `Core.lua`, `Tracks.lua` and `Zones.lua`:

| Probe | Result |
|---|---|
| Audio API used | **`PlayMusic` only**, 16 calls |
| `C_Sound.*`, `volumeOverride`, `runFinishCallback`, `MuteSoundFile`, `StopSound` | **zero** |
| The string "ambience", anywhere | **zero** |
| Weather, rain, `SetBlendMode`, `CreateTexture` | **zero** |
| Time of day | a binary night check, `hour >= 21 or hour < 6` |

So it is music, on the music channel, with no ambience, no weather, no visuals and no
mixing. It cannot reach a player who has `Sound_EnableMusic` off, which per all three
reports is a large share of the audience.

**Two things follow.** It is a positive control for the whole audio thesis: FileDataID
scheduling demonstrably works on a live Forever client *today*, which was previously only
inferred from binary strings. And the `C_Sound` params path we found is still unexploited
by anyone, FAME included.

### What all three reports agreed on

Treat as settled; none of it was contradicted and each has independent support.

1. **Ambience is the default, music is opt-in.** Music-off is common and the stated cause
   is repetition, not dislike. Ambience does not fatigue the same way and, decisively, it
   survives `Sound_EnableMusic = 0` — a music station cannot reach that audience without
   hijacking their ambience channel, which is what EpicMusicPlayer does and charges for in
   muted ambience.
2. **One addon, not two.** Same inputs drive all outputs, so splitting risks visual and
   audio rain desynchronising. Mitigation is unanimous: the post-rename default must behave
   exactly as today, with audio opt-in and the old slash commands intact.
3. **The second browser tab is the real competitor and context is the only edge.** A lo-fi
   tab has unlimited content and zero setup. It cannot know you just walked into an inn, or
   that it is 2am, or that the sky is grey. Design to play *under* the tab, not against it.
4. **Brand plus descriptive subtitle.** A name with no searchable word costs real
   discovery; CurseForge has ~31k WoW projects and search is the primary vector.
5. **"Cozy", not "comfy".** Two of three, with evidence: "cozy" is native to this audience
   (the Cozy Sleeping Bag item, housing content), "comfy" reads as imageboard and Twitch
   slang.
6. **User-supplied OGGs are a power-user tail.** Support a folder, never depend on it.
7. **Micro-sequencing is the world-class feature**, proposed independently by all three.
   Chain and vary beds via `runFinishCallback` instead of looping one file, which is exactly
   what myNoise's Animate and Noisli's oscillation do — the converged answer to loop fatigue
   after fifteen years of commercial ambient audio.

### Where they split, and the calls

- **Name.** Hearthlight / AzerothAmbience / "CozyWeather: Ambient Mood Engine". Rejecting
  all three as given: `Hearth*` grazes a Blizzard trademark, and "CozyWeather" re-caps the
  product at weather, which is the exact trap we are leaving. The pattern is right, the
  brands are not.
- **The folder name is the only irreversible part.** Renaming it breaks every user's
  SavedVariables. Pick it once, keep it short and scope-free, and let the CurseForge title
  and TOC title carry the keywords, since those are free to change later.
- **Download figures.** Report 3's Ring 1 numbers conflate per-file with per-project counts
  (EpicMusicPlayer as 697 against the other two reports' ~600k). Reports 1 and 2 agree with
  each other and are the ones to trust. Report 3 found FAME, which neither of them did.

### One modification to their unanimous launch advice

All three said: ship the visuals for 4 November, add audio after. That ships the **weak
half** first — the visual ceiling is the low one and it is already documented as
unreachable territory against Blizzard's 3D particles.

Better wedge: **visuals plus an ambience bed**, which is nearly what exists today, since
the rain audio bed is already built and already prefers Blizzard FileDataIDs. Ambience is
the half nobody occupies, FAME structurally is not going there, and it reaches the music-off
audience. The music station stays post-launch.

## The scope question we never asked: is this an audio product?

Raised 2026-10-12. Every consult, all three deep-research reports and the whole roadmap
below treat this as a **visual** addon with a soundtrack. Audio appears in the proposed
effect schema as one sub-field of a visual layer — `{ loop fdid, len, oneshots[] }` — and
nowhere as the thing itself. That framing came from the prompts, which asked for the best
*weather* addon; nobody pushed back because nobody was asked to.

It is probably backwards, and the binary is why.

### The two ceilings are nowhere near the same height

The visual ceiling is **hard and low**, and already documented below: a MOD-blend quad over
a 2D sheet is the only darkening available. No world fog, no lighting, no framebuffer read,
no camera pitch, no occlusion. Blizzard's rain is 3D particles in world space and we will
never be in the same category.

The audio ceiling is **high**, and higher than we had assumed. Probed in the 1.60.1.70338
binary 2026-10-12 (positive control `GetUnitSpeed` = 2 hits):

| Symbol | Hits | What it buys |
|---|---|---|
| `C_Sound.PlaySoundWithOptions` | 1 | A params table, not a bare call |
| `volumeOverride` | 1 | **Per-sound volume.** The limitation the whole audio design works around |
| `runFinishCallback` | 1 | Fires when a sound ends — the sequencing primitive |
| `C_Sound.IsPlaying` / `GetSoundScaledVolume` | 1 / 2 | Query a live handle |
| `MuteSoundFile` / `UnmuteSoundFile` | 3 / 3 | Silence specific Blizzard files by FileDataID |
| `PlayMusic` / `StopMusic` | 2 / 1 | The music channel, separate from SFX and Ambience |
| `Sound_EnableMusic` / `_EnableAmbience` / `_EnableSFX` | 1 each | Per-channel suppression |

`volumeOverride` and `runFinishCallback` sit in the C_Sound string region between
`uiSoundSubType` and the `GetSoundScaledVolume` usage line, which is strong evidence they
are fields of the `PlaySound`/`PlaySoundWithOptions` params table but is **adjacency, not a
declared struct**. Confirm with `/dump C_Sound` and `/api C_Sound` in a running client
before building on them.

**Immediate consequence:** the five pre-baked gain variants exist only because
`PlaySoundFile` has no volume argument. `volumeOverride` does. That ladder is obsolete
engineering and should collapse into real crossfades on a single file.

### What "radio station" can and cannot mean

It **cannot** mean internet radio. There is no HTTP in the addon sandbox and there never
will be. Nor can we ship music — bundling audio is redistribution and it is the single most
reliable way to get an addon pulled.

It **can** mean a programme director over the game's own sound library. Every ambient loop,
zone theme, tavern track and weather bed Blizzard ships is addressable by FileDataID, which
plays the user's own installed files and redistributes nothing — the same mechanism already
used for rain, with the same legal standing. Add `MuteSoundFile` to suppress what the engine
would have played, `runFinishCallback` to sequence, `volumeOverride` to mix, and that is a
station: scheduled, zone-aware, weather-aware, and driven by the apparent-hour clock the
addon already computes.

Nobody in the competitive survey has built this. Weather does indoor muffling and skyriding
wind; Dynamic Weather has a soundkit ID per state. A scheduler over the library is unoccupied.

### The call

The audio half is the bigger product and the better-defended one, because the differentiator
is scheduling rather than pixels and there is no Blizzard implementation to lose to.

It does **not** change the next nine days. Calibration expires with the beta client on
21 October; none of the audio work does, and the client is there from 4 November onwards.
Bank the finding, take the `volumeOverride` simplification when the audio ladder is next
touched, and revisit the product shape after launch — not before the calibration session.

## Round 3 research, 2026-10-14: the sequencing primitive is not what we thought

Report 1 against `dr-prompt-name-and-scope.md`. It confirmed the name and attacked the audio
plan, which is the right way round. Its two audio corrections were checked against the
binary before being believed; one was partly wrong and the engineering consequence survives
either way.

### What the binary says, re-probed 2026-10-14 (control `PLAYER_LOGIN` = 1 hit)

| String | Hits | Offset | Meaning |
|---|---|---|---|
| `SOUNDKIT_FINISHED` | 1 | 81230320 | **The finish signal is an event, not a Lua callback** |
| `uiSoundSubType` / `forceNoDuplicates` / `runFinishCallback` / `overridePriority` / `volumeOverride` | 1 each | 81780880 to 81780968 | A contiguous field block, immediately before the two usage strings below |
| `Usage: local success, soundHandle = C_Sound.PlaySound(params)` | 1 | 81781216 | Takes a **params table** on this build |
| `Usage: local success, soundHandle = C_Sound.PlaySoundWithOptions(params)` | 1 | 81781280 | Same |
| `Usage: StopSound(soundHandleID, [optional: fadeout time in ms])` | 1 | - | **The crossfade primitive, confirmed** |
| `Usage: PlaySoundFile("soundFile" or soundFileID, optional["SFX","Music","Ambience" or "Master"])` | 1 | - | No volume argument, which is why `volumeOverride` matters |
| `Usage: MuteSoundFile("soundFile" or fileDataID)` | 1 | - | Takes a FileDataID |

Two things change. The 2026-10-12 note that `volumeOverride` and `runFinishCallback` are
"adjacency, not a declared struct" is **superseded**: they sit in a field-name block four
strings long that ends at the `PlaySound(params)` usage line, and `forceNoDuplicates` is a
known param of the same call. `overridePriority` is a field we had not recorded. And the
report's claim that `runFinishCallback` belongs to a positional `PlaySound(soundKitID, ...)`
is **wrong for this build** - there is no such usage string; `C_Sound.PlaySound` takes
params here too.

**The substance of its correction stands anyway, and it is the part that matters.**
`runFinishCallback` does not call anything. It arms the `SOUNDKIT_FINISHED` event, and
whether that event fires for FileDataID playback is still unknown. So:

**Decision: the sequencer is timer-driven.** Store each file's measured duration, schedule
the next with `C_Timer`, and crossfade with `StopSound(handle, fadeoutTime)` on the outgoing
handle. `SOUNDKIT_FINISHED` becomes an optional accuracy improvement if the client test
proves it fires for files, never the mechanism. This is also what the mock already models,
so no spec changes.

### The second correction, unverifiable here and more dangerous

Warcraft Wiki says `MuteSoundFile` "works on all internal game sounds, addon sounds and
sounds played manually by PlaySoundFile()", and that mutes **do not survive a client
restart**. If true, the "mute Blizzard's rain, play our own" plan silences our own playback
of the same FileDataID, and every mute must be reapplied on `PLAYER_LOGIN`. Cannot be
checked from strings. **Goes on the client test list.**

### The three tests that must happen before 21 October

The client is at `~/Games/battlenet/pfx/drive_c/Program Files (x86)/World of Warcraft/_classic_beta_/WowB.exe`.

1. `/dump C_Sound` and `/api C_Sound` - the real field names of the params table.
2. Play a FileDataID with `runFinishCallback` set, register `SOUNDKIT_FINISHED`, see whether
   it fires.
3. `MuteSoundFile(id)` then `PlaySoundFile(id)` - does our own playback survive the mute.

### Discovery: the launch date is not the event we thought it was

The Forever addon market opened during beta, not on 4 November. Observed 2026-10-14:
GearQuest 445,258 downloads, Spoken 114,238, ClassicUI Forever 101,990, Overlord Forever
66,887, Forever Guide 60,164, and **5,173 Forever-flavour projects already listed**.

**The Spoken benchmark is deflated.** It is not Forever-only (flavours Forever, Classic and
Classic TBC), it absorbed Voiceover Redux and ZoneLore so it inherited their users, several
voice-pack meta-packages list it as a dependency, and about 20 releases in 25 days means
existing users re-download. Its real lesson is mechanism, not velocity: daily downloads went
from ~6.5k to 9.9k to 13.8k immediately after Team Overpowered published a video on
11 October framed as **immersion**. That is the channel this product fits.

**Schedule consequence:** submit the project as `Duskfall` on **27 October**, the day name
reservation opens, so it clears moderation before launch. Ship 4 November. The window that
sets the ceiling is days 7 to 30, while creators are making "Forever addons you need" lists.

### The name does not survive, and the report's own evidence is why

The round cleared Gloaming on collisions: no WoW addon, no WoWInterface addon, no GitHub
WoW repo. What it found instead was a USPTO bedding mark (class 24), a cosmetics mark, an
Android DND tool, a Google Play generative-sunsets app, three Steam titles, an Irish band on
Real World Records, a Radiohead subtitle and an Australian TV series. **None is in the
channel that matters.** Do not file a trademark either: USD 350 per class buys nothing for a
free addon whose legal position rests on Blizzard's goodwill rather than trademark law.

It also found, and buried under "one real weakness", that every dictionary tags *gloaming*
as literary or poetic and that it is spelled *glowing* when heard once. **That weakness was
the verdict and the report scored it as a footnote.** See `## The name: Duskfall` below. The
same round's finding that the brand carries no search load is what makes comprehension the
brand's only remaining job.

### Open items this round added

- The report could not reproduce the CurseForge search check; its fetcher dropped the query
  string and returned the unfiltered browse page. The 2026-10-13 browser result stands, but
  **re-run it in a browser and screenshot it next to `?search=CozyFire` as the control**
  before the folder name is committed.
- The `AlwaysRainDB` migration has a dependency nobody had noticed: **the old SavedVariables
  file is named after the **folder**, so it only loads if a folder of that name is still
  installed. Resolved 2026-10-14: `## OptionalDeps: AlwaysRain` is in the TOC, and no stub
  folder ships, because the addon has never been published and the only install that can
  reach this path is the author's. Still untested on the client.

## The name: Duskfall

**Superseded 2026-10-19 by Comfy Rain.** Everything below is the
record of how Duskfall was chosen on 2026-10-14 and is left as written. Historical
mentions of `Duskfall` elsewhere in this file are also left alone on purpose: a decision
log that is search-and-replaced stops being evidence of what was actually checked.

**Settled 2026-10-14, third pass. `Gloaming` is dead and `Cozy Azeroth` before it.**
`AlwaysRain` is a feature name that caps the product at one weather type and already fights
a roadmap containing snow, fog, ash and time-of-day.

| Field | Value |
|---|---|
| Folder (**irreversible**) | `Duskfall` |
| TOC `## Title` | `Duskfall` |
| CurseForge title | `Duskfall: Rain, Weather and Cozy Ambience` |
| Slash | `/dusk`, with `/rain` kept as a permanent alias |
| SavedVariables | `DuskfallDB`, migrating from `AlwaysRainDB` on first load |

### Why Gloaming died after one day

the author, on reading it: *"what the fuck is gloaming that isnt a word anyone knows its
stupid"*. He is right, and the research round had already found the same thing from the
other end without weighting it properly: every dictionary tags *gloaming* as **literary**
(Merriam-Webster), **literary or Scottish** (Cambridge) or **poetic** (Collins), it is
pronounced "GLOH-ming", and heard once in voice chat it is spelled *glowing*.

**The lesson, which is the reusable part.** The same research established that the brand
name carries **no search load at all** - the subtitle does all of it, because users type
"rain", "weather" and "ambience", never the brand. Once that is true, the only job left for
the brand is to be *said, heard, spelled and remembered*. Picking a word that fails the
first requirement of its only job was the error. Obscurity was being scored as distinctiveness.

A name nobody can spell is not distinctive, it is unfindable the one time it matters: when
somebody tells a friend about it out loud.

### Why Duskfall

It keeps every property that made Gloaming right and drops the one that killed it.

| Test | Gloaming | Duskfall |
|---|---|---|
| Honest about the renderer: MOD blend can only *darken* | Yes | Yes, dusk is the dim half of the day |
| Caps nothing: not a weather type, not an audio word | Yes | Yes |
| No `ever` substring (the Forever namespace rule) | Yes | Yes |
| No WoW mechanic word (cast, rest, proc) | Yes | Yes |
| Native WoW register | Gloaming Reef, Gloaming Powder | Duskwood, Duskwing, Duskhaven |
| **Understood on hearing it once** | **No** | **Yes** |
| Spelled right on hearing it once | No, lands on *glowing* | Yes, two common words |

**CurseForge, checked 2026-10-14 with a positive control.** The instrument is
`curseforge.com/wow/search?search=<term>`. Control: `CozyFire` returns **1 project, the
known one**, so the method finds what exists. `duskfall` returns **0 projects**. (Bare
`dusk` returns 21, but only Duskwatch at 120 downloads and Dusk Lure Tracker at 356 are
actually named Dusk-anything; the rest are fuzzy hits on Tuskarr, Dust and Medusa.)

**Why not bare `Dusk`:** DUSK is a well-known 2018 indie FPS by New Blood, which is a
louder general-search collision than anything Duskfall has, and a four-letter word is
harder to own.

**Duskfall's own collisions, checked 2026-10-14, none in the channel that matters:** The
Duskfall, a Swedish melodic death metal band formed 1999; *Duskfall*, a 2024 mobile
Wizardry-like; *DUSKFALL*, a 2025 Steam village-defence game by KafkaStudio; and
"duskfallcrew", a music and content creator. **No WoW addon, no WoW repo, nothing in
CurseForge or an addon manager.** Same class of harmless cross-category noise that Gloaming
had, and it does not reach a free addon.

Follow-on: the addon's own `/rain gloom` subcommand becomes **`/dusk dim`**, keeping
`gloom` as a hidden alias.

The title changed on 2026-10-14 from "Weather, Ambience and Time of Day" to **"Rain,
Weather and Cozy Ambience"**. Nobody searches for time of day; "rain" is the literal product
today, "weather" is the category word every competitor is named with, and "cozy" has
existing CurseForge supply.

**Only the folder name is expensive to change** — renaming it orphans every user's
SavedVariables, because the file is named after the folder. The displayed title, the
CurseForge title and the description are all free to revise later, which is why the brand
goes in the folder and every search keyword goes in the title.

Why this and not the three the reports proposed:

- **Hearthlight** (report 1) grazes *Hearthstone*, a live Blizzard trademark, in an addon
  whose entire legal position rests on Blizzard's goodwill. Not worth it for a name.
- **CozyWeather** (report 3) re-caps the product at weather, which is the exact trap being
  escaped.
- **AzerothAmbience** (report 2) has the right structure but caps the other way, at audio,
  and the product is both halves.
- **"ComfyVibes"**, the original instinct, is right about the feeling and wrong about the
  word. Two of three reports found, with evidence, that *cozy* is native to this audience
  (the Cozy Sleeping Bag item, housing content) while *comfy* reads as imageboard and
  Twitch slang. "Vibes" also carries no search weight.

### Why Cozy Azeroth died, 2026-10-13

It was decided earlier the same day on reasoning alone. Nobody had run a single search. Two
checks killed it, and a third killed its replacement.

| Check | Result | Verdict |
|---|---|---|
| Is `CozyAzeroth` a creator brand? | **Yes.** YouTube channel "Zachary Fruhling (Fruhling Designs / CozyAzeroth)", videos titled "CozyAzeroth: Casual WoW & Housing Decor Hunt" and "CozyAzeroth: Casual Sunday WoW" | Same game, same cozy/housing niche, identical string |
| Is `Cozy*` crowded on CurseForge? | **Yes.** Cozy Companion, CozyCamps, and **CozyFire** (732 downloads, flavour Forever, updated 13 Oct 2026) | Would have launched as the fourth Cozy, behind one actively shipping on this exact client |
| Is any addon called Cozy Azeroth? | No | The collision is a brand and a prefix, not an addon |

A two-model consult (Gemini 2.5 Pro and GPT-OSS-120B; **Grok 403'd on credits again, so this
was two models, not three**) was unanimous that the name had to change, and split on whether
the crowded prefix is a penalty or proof of a category worth joining.

**The split was settled with data neither model had.** All three `Cozy*` addons sit in the
hundreds of downloads (471 to 990), while the Forever-native hits that actually move -
Spoken Player at 97,856 in 24 days - carry no such prefix. The prefix is not doing
distribution work, so there is nothing to join. GPT-OSS's case for keeping it also rested on
two fabrications: that addon managers rank alphabetically then by downloads, and a "Nihilum
UI / popular forum user" precedent. Both discarded.

### The three candidates the search killed, and the rule each produced

Worth keeping, because each is a reusable filter and all three were found in minutes with
`https://www.curseforge.com/wow/search?search=<term>`, which is the right instrument: it is
CurseForge's own fuzzy matcher, so it shows what a user's search would actually surface.

1. **Evermood** (Gemini's pick) → **no name may contain `ever`.** Searching *reverie*
   returned **1,207 projects**, almost all of them Forever addons, because the fuzzy match
   catches `ever` inside `Forever`. On a client called Forever that substring is the single
   most polluted in the namespace. Separately, `Evermore UI` and `Forevermore Classic UI`
   already exist.
2. **Overcast** → **no name may contain a WoW mechanic word.** Free as a name, but the
   search returns 32 castbar addons (HoverCasts, PlayerCastBars, FocusCastbarMover). To a
   WoW player *cast* means spellcasting before it means weather.
3. **Cozy Echoes** (GPT-OSS's pick) keeps the dead prefix and leans audio-only. Rejected on
   the evidence above.

**Gloaming**, by the same instrument: **1 project returned, unrelated** (a herb and mining
tracker). Clean on collisions, and killed the next day on comprehension instead. **Duskfall**
returns **0 projects**, control `CozyFire` = 1.

A note on method, so it is not repeated: **`curl` against a Twitch channel URL is not an
existence check.** It returns HTTP 200 for a channel that cannot exist; a nonsense handle was
tried as a control and also returned 200. The CozyAzeroth brand finding rests on the YouTube
channel name and video titles, not on that status code.

## SCOPE FREEZE, 2026-10-18 — the finish line

**This section supersedes the feature work in `## THE ROADMAP` below.** The roadmap's
dates and its Phase 1 client-gated list still stand; its Phase 2/3/4 feature list does not.

### Why the scope froze

Three deep-research reports came back on the question "is this worth building" (the prompt
is `dr-prompt-is-this-worth-building.md`). They disagreed on the verdict — reshape, abandon,
ship-if-reframed — but **none of the three said ship as-is**, and they converged on the
numbers:

| Addon | Downloads | Note |
|---|---|---|
| Dynamic Azeroth Weather | 359 in 6 months | near-identical feature list to ours |
| keyboardturner's Weather | ~2,300 lifetime | reacts to server weather, does not fake it |
| Dynamic Weather (best ever) | 20,860 lifetime | abandoned 2021 |
| Our 90-day ceiling, 2 of 3 reports | low hundreds | the third said 3,000-8,000 and was internally inconsistent |

Also unanimous across all three:

- **Skyboxes are impossible for an addon.** Three for three. The claim recorded in
  `## What this can never match` was challenged, put into the research prompt rather than
  argued, and came back confirmed. It is now settled; do not re-litigate it.
- **There is a real fog/atmosphere backlash.** Eye strain, headaches, and Blizzard removing
  `/console volumeFog 0` as "unintended". Our MOD darken quad and gloom grade sit on the
  wrong side of that sentiment.
- **Blizzard has been actively increasing weather since 23 September** and shipped
  environment-lighting lightning on 16 October, which weakens the "weather is rare" half of
  the thesis. The "on demand, anywhere, permanent" half is untouched and is still the pitch.

The conclusion is not that the addon is bad. It is that **the remaining engineering spend
is not justified by a few hundred downloads.** So: ship what exists, stop building.

### Cut, explicitly

Each of these was planned and is now out of scope. They are recorded here so a later session
does not pick one up thinking it was forgotten.

- The depth gradient and the near-layer radial mask (consult item 1).
- Parallax from `GetPlayerFacing()` (consult item 2).
- Located lightning with `delay = metres / 343` (consult item 3).
- Standing aside for a real server storm (consult item 4).
- Regenerating `rain-near` / `snow-near` / `snow-gale` at 1024² (consult item 5).
- Lens drops and the ground-wet MOD gradient (consult item 6).
- Drifting cloud-shadow dimming. Added verbally after the skybox thread; all three reports
  warn it reads as a cheap muddy filter, and the fog backlash says the same.

### A. Bugs from live play — done 2026-10-18

Both were reported from actually playing, which is the only source of this quality of bug,
and both were real.

1. **"Audio doesn't start quickly."** The first bed layer always started at once. The second
   waited `random() * len * 0.6`, and `len` is 30s for rain and 50s for snow, so the bed
   could stay a single thin loop for **up to 18 or 30 seconds** after the player turned rain
   on. Capped at `UNDER_FIRST_MAX = 2.5`. The initial offset was never what decorrelates the
   two layers — the per-relaunch jitter in `BedInterval` is — so nothing is lost.
2. **"Rain goes through indoors sometimes."** `IsIndoors()` and `IsOutdoors()` are **not
   complements** on this client (both verified present in `WowB.exe`, positive control
   `GetPlayerFacing`). A WMO interior sets the first; open world sets the second; awnings,
   cave mouths, tents, bridges and most doorways set **neither**. The old test asked only
   `IsIndoors()` and so read every one of those as open sky. Now `Sheltered()` treats
   "neither" as indoors. The debounce is also asymmetric now — 0.35s to take cover, 1.2s to
   leave it — because rain through a roof is the reported error and a second of missing rain
   outdoors is not.

   The test mock modelled the two as strict complements, which is why this bug lived in a
   green suite. `test/wowmock.lua` now has a third state, `state.sheltered`.

### B. Ship scope — packaging only, no new features

Everything here is mechanical. None of it needs a running client.

**Done 2026-10-18:**

2. `README.md` (player-facing, states the screen-space limits up front) and an MIT `LICENSE`
   that says in words that Blizzard's sounds are played by FileDataID, not redistributed.
3. TOC: real `## Author`, `## Version: @project-version@`, `## IconTexture`, `X-Website`,
   `X-License`, `X-Category`. `Probe.lua` is wrapped in `#@do-not-package@` so it stays
   installed for local work and never reaches a player.
4. `.pkgmeta`, `CHANGELOG.md`, `.github/workflows/release.yml` (pinned
   `BigWigsMods/packager@v2.6.1`) and `.github/workflows/ci.yml` (luac syntax check, the
   156-spec suite, and a build of all four asset generators).
   - `build/make_icon_tga.py` is new: a 64x64 dusk-and-rain icon, checked legible at 20px.
   - `install.sh` now substitutes `@project-version@` with `dev-<sha>` and builds the icon.

**The packaging finding, which cost a silently broken release.** The BigWigs packager
**honours `.gitignore`**. Running `build/make_*.py` into `Duskfall/` before it is therefore
*not* enough: the assets sit on disk, every one of them is skipped, and the zip installs
perfectly with no rain and no sound. This was caught only by downloading the pinned packager
and running it locally, then unzipping the artifact. Two consequences, both load-bearing:

- The workflow `git add -f`s the `.tga`/`.ogg` files into the throwaway CI checkout before
  packaging. That force-add is the entire mechanism by which assets reach the archive.
- The verify step **unzips the artifact** and asserts 11 non-empty files, no `Probe.lua`, and
  no unsubstituted `@project-version@`. Checking the working directory would have passed on
  the broken build, because the directory was never the thing that was wrong.

Verified locally end to end: `move-folders` lifts `Duskfall/Duskfall` to `Duskfall`, the
version token substitutes, `Probe.lua` is stripped, flavour auto-detects as `forever` from
`## Interface: 16001`, zip is 716K.

**Item 1 was dropped on evidence, not forgotten.** "Default the MOD darken quad to off" was
tried — `gloom = 0.6` — and reverted. The preset curve under that multiplier is not a guess:
the 2026-10-15 screenshot sweep measured normal rain darkening the scene by 0.7% and *raised*
gloom from 0.20 to 0.38 to compensate, because the light-coloured rain sheets add back more
than the old curve removed. 0.6 re-opens the exact bug that sweep closed, and it failed the
spec that pins it. The murk the reports object to lives at `heavy`/`monsoon`, which a player
picks deliberately, on an effect they turned on, with a Darkness slider in the window. That
is consent; Blizzard's undisableable fog was not. The reasoning is in a comment on `DEFAULTS`
so it is not re-tried blind.

5. **The repo exists: `LibruaryNFT/duskfall`, pushed, CI green.** Created **private**
   deliberately, not as an oversight. This file is in it, and this file contains the
   download ceilings, the kill number and four research prompts. Flipping it public is one
   command and is the author's call, not the agent's:

   ```
   gh repo edit LibruaryNFT/duskfall --visibility public --accept-visibility-change-consequences
   ```

   Either flip it, or add `RESUME.md` and `dr-prompt-*.md` to a `.gitignore` first. Nothing
   else in the repo is sensitive.

**The release pipeline is proven, not assumed.** Four rehearsal tags, `v1.0.0-rc1` through
`v1.0.0-rc4`, were cut against the real workflow rather than reading it and hoping. Three of
the four found a separate defect that would have hit the launch tag on 4 November. All four
defects are invisible to review and two of them are **silent** — green check, exit 0, nothing
shipped.

| Rehearsal | What broke | Why no error |
|---|---|---|
| rc1 (CI, pre-tag) | `make_rain_audio.py` shells out to `ffmpeg`, absent from the runner | bare `FileNotFoundError`, named neither audio nor ffmpeg |
| rc1 | zip named `Duskfall-v1.0.0-rc1-1-g7935820`, and no release published | the asset commit moved HEAD past the tag, so the packager built an alpha; **exit 0** |
| rc2 | verify's own `grep -qx '## Version: ...'` never matched | the packager writes a **CRLF** `.toc`; the line ends in `\r` |
| rc3, rc1 | **no GitHub release at all** | the packager reads `GITHUB_OAUTH`, never `GITHUB_TOKEN`; `upload_github` opens with `[[ -z "$github_token" ]] && return 0`; **exit 0** |

The `GITHUB_OAUTH` one is the dangerous one and is worth reading twice. `release.sh` accepts
exactly `GITHUB_OAUTH` and `GITHUB_API_TOKEN`. Pass `GITHUB_TOKEN` and it builds a perfect
zip, prints "Packaging complete", uploads nothing, and succeeds. Its own banner is the tell:
`GitHub: owner/repo [token set]` when the token is readable, and it stops at the slug when it
is not. Both failing logs stopped at the slug.

Two guards were added so none of this can recur quietly: the verify step asserts `## Version`
equals the bare tag and the zip name carries it, and a final step asks the **GitHub API**
whether the release exists and has the zip attached, because the packager's exit code is not
evidence that it does.

Proven by downloading the published `v1.0.0-rc4` artifact and unzipping it: 15 files, all
three rain/snow texture pairs, `icon.tga`, both `.ogg`, `## Version: v1.0.0-rc4`, no
`Probe.lua`. `v1.0.0-rc4` is left on the repo, marked prerelease, as the working reference.

**Still open:**

6. One 10-second looping GIF for CurseForge, Reddit and Discord. **There is a real still in
   place meanwhile**: `docs/preview.jpg`, cropped from `WoWScrnShot_101526_121107.jpg` - an
   actual in-game frame of heavy rain over the Trade District, UI cropped out and two other
   players' nameplates blurred. It is honest, not a mock-up, and it is the README hero now.
   But rain is motion and a still undersells it, so the GIF still wins. One line to swap.

   **Capture it in the same sitting as the section C list below**, because it needs the
   client and the client dies on 21 October. It is about two minutes:

   - `/dusk heavy`, find a street with sky in frame (the Trade District shot above is a good
     one), `Alt+Z` twice to hide the UI.
   - `Ctrl+Alt+Shift+R` starts GNOME's recorder, same keys stop it. Record ~12 seconds,
     turning the camera slowly through about 90 degrees so the parallax reads. It lands in
     `~/Videos/Screencasts/`.
   - Do a second take on `/dusk snow` and a third on `/dusk blizzard` while you are there.
     Three takes cost a minute and the one that looks best cannot be known in advance.
   - Leave the files. ffmpeg is on this box; the agent crops, trims and converts to a GIF.
7. The CurseForge project itself, then `## X-Curse-Project-ID` in the TOC and a `CF_API_KEY`
   repo secret. The workflow publishes to GitHub without it rather than failing, so a tag
   pushed before the project exists still produces a downloadable release.

### B2. Hardening, 2026-10-18 — 150 specs to 156

Not features. Each one is a crash a player could hit that no amount of play-testing here
would find.

- **A saved profile is now sanitised, not merely filled.** The old merge was
  `if db[k] == nil then db[k] = v end`: correct for an absent key, and it does nothing at all
  for a present key of the wrong type. A `DuskfallDB` carrying `scale = "loud"` — a truncated
  file, a hand edit, a migration from some future version — loaded without complaint and then
  threw inside the per-frame arithmetic. That is an error **every frame, forever**, fixable
  only by deleting a file the player does not know exists. `SanitiseProfile()` type-checks
  every key against `DEFAULTS`, clamps numerics to the **slash parser's own ranges** rather
  than a second invented set, validates `weather`/`channel`/`timeMode`/`indoors` against
  their valid sets, and rewrites the legacy boolean `indoors`. A numeric string like `"0.5"`
  is kept, because that is a value the player meant.
- **`DuskfallDB` itself is type-tested.** It was `DuskfallDB or {}`, and a half-written file
  reads back as a string, which is truthy. We already guarded the *old* AlwaysRain table that
  way; ours was no less likely to be the truncated one.
- **Drop shape is pinned from 4:3 to 32:9**, plus 5:4, 16:9, 21:9 and 4K, as the invariant
  `tilesX / tilesY == aspect` rather than six hard-coded numbers.
- **Every fullscreen quad is asserted anchored to its parent**, which is the only part of
  "check the quads at 21:9" that is answerable without a client.

Every new spec was mutation-checked: each one was confirmed to FAIL against the code it
replaced. A green spec that cannot go red is the thing that let the indoor bug ship.

### C. the author's hands — client-gated, expires 21 October

Three days left. Nothing in this list can be done after the beta client dies, and none of it
can be done by the agent.

- `/dusk probe` on build 70425. The results on disk are from 70374.
- `/dusk calib on`, then play normally. This measures how often the server actually sends
  weather, and it is the stated kill number for the thesis.
- During a real storm, set `weatherDensity 0` and watch whether the **engine lightning**
  stops too. The reports split on this: two say 0 suppresses precipitation, one says a
  28 September beta tester found it no longer does, and the third says it suppresses
  precipitation but not the new lightning.
- Fully exit and relaunch to answer the TOC flavour question, staging the flavour probe into
  `_forever_` rather than `_classic_beta_`.
- Check the fullscreen quads at 21:9 and at several `UIParent:GetScale()` values. Partly
  covered headless now (anchoring and drop shape are pinned in specs), but the scale half
  is not testable here: the overlay is parented to `WorldFrame`, which the mock cannot scale,
  so a spec for it would only be asserting the mock. Eyeball it.

### The kill number

Fewer than ~200 downloads at 30 days post-launch means the category ceiling is real and
there is no second version. That is the measurable thing, decided in advance, so it is not
re-argued later from enthusiasm.

---

## THE ROADMAP

The one plan. Supersedes every other schedule in this file. Revised 2026-10-13 after a
second consult (Gemini 2.5 Pro and GPT-OSS-120B, `review-{gemini,groq}-2026-10-13.md`) which
attacked the previous version and was right twice.

Three fixed dates. Beta client dies **21 October**. Name reservation **27 October**. Game
launches **4 November, 3pm PST**. Today is 13 October, so there are 8 days of client access.

**Two ordering principles.** Work is ordered by what *expires*, not by what is interesting
or nearly done. And, added 2026-10-13: **code that has never been run does not ship to
strangers on a day it cannot be hotfixed.**

### The launch is split, and that is the change

The previous version shipped everything on 4 November, including a refactor, a GUI, a
serialiser and an audio subsystem all written during the 14 days when no client exists. Both
consult models independently said that blind-shipping, not Phase 1, is the real risk, and
both independently proposed delaying to 11 November.

They are right about the risk and half right about the fix. Delaying wholesale gives up the
one day the addon can be found without search ranking. So:

| Date | Ships | Why |
|---|---|---|
| **4 Nov** | Only what Phase 1 verified on a live client: rain, sky grading, time of day, the ambience bed, the rename | Captures the launch-day discovery window with code that has actually been run |
| **~11 Nov**, as v1.1 | The options panel, preset sharing, and anything else written blind | A week of live-client testing first, on a client that exists again from 4 Nov |

This also fixes something both models missed. **The existing v2 code has never been seen
running either** (see `## Open / unverified`), so Phase 1 is not only the chance to answer
seven questions, it is the only chance to validate what is already written. That makes the
split the natural shape rather than a compromise: 4 November ships the verified subset,
11 November ships the rest.

### Who does what

This matters more than it looks. **Phase 1 is entirely the author's hands** — it needs a logged-in
client and the agent has no game access. Everything in Phase 2 except the CurseForge
submission is entirely the agent's. If Phase 1 does not happen in the next 8 days it cannot
be recovered, and no amount of agent time substitutes for it.

| Phase | Whose hands | Expires |
|---|---|---|
| 1 — client checks | **the author**, in-game | **21 Oct, permanently** |
| 2 — build and publish prep | Agent | 4 Nov (soft) |
| 2 — CurseForge submission | **the author** (account, approval) | **this week**, with placeholders |
| 3 — launch | Agent tags, the author posts | 4 Nov |
| 4 — after | Agent | never |

### Probe results, build 70374, 2026-10-14

Read off `DuskfallDB.probe` on disk, not transcribed from chat. **Build is 70374, not the
70338 the earlier notes assumed.**

| Check | Verdict | What it means |
|---|---|---|
| `savedvars` | **yes** | token `1792022831-8399` survived a reload. Both launch blockers are unblocked |
| `ambience_musicoff` | **yes** | `willPlay=true` with `Sound_EnableMusic` forced to 0, **and the player heard it**. The entire ambience-led product thesis holds |
| `settings_panel` | **yes** | category ID 23, `RegisterAddOnCategory=true`. `AddSearchTags` still raises, as expected |
| `c_sound` | **yes** | `GetSoundScaledVolume, IsPlaying, PlayItemSound, PlaySound, PlaySoundWithOptions, PlayVocalErrorSound` |
| `mute_reload` | **yes** | the mute survived the reload, so it must be reapplied deliberately, not assumed gone |
| `geometry` | **yes** | 2127x1080, aspect 1.969, `UIParent` scale 0.711, interface 16001 |
| `mute_self` | **yes, and it is bad news** | control `willPlay=true`, muted `willPlay=nil`. `MuteSoundFile` silences OUR playback of the same file too |
| `weather_model` | **yes** | 166249 loaded, `GetModelFileID=166249`. A loaded model is still not a visible one |
| `sound_params` | **yes** | the id key is **`soundKitID`**, accepted first try once the call passed one table |
| `finish_event` | **no** | SoundKit fired, FileDataID did **not** (`fileOk=nil`). Answered with its positive control, so this is a result, not a gap |
| `screenshots` | **yes** | 10 shots, control included, so `Screenshot()` is not blocked and an empty folder would have meant something |

**Three consequences.**

1. **The suppression plan needs rebuilding.** `mute_self` was supposed to let us silence
   Blizzard's rain and play our own bed over the silence. It does not: the mute is keyed on
   the file, not the caller, so muting `RainMediumLoop.ogg` mutes us playing it too. The bed
   has to use a *different* file from the one being suppressed. Cheap to fix, but it would
   have been found by a user, not by us, if this check had not run.
2. **`settings_panel` passing retires Phase 1 item 7 as a blocker and adds a feature.** The
   self-drawn window already removed the dependency; this says we can *also* register in the
   client's own Settings list as a second way in, which is where a non-power-user looks first.
3. **`finish_event` is reachable, and the error handed us the signature.** It takes one
   `params` table. The key holding the sound id is still unknown, so the probe no longer
   guesses: it tries `soundKitID`, `soundKitId`, `soundkitID`, `soundFileID`, `soundID` and
   `id`, records the client's reply to each, and only then asks the finish question. A run
   that accepts none records `sound_params = no` and `finish_event = unknown`, because a call
   that never reached the client cannot retire a Phase 4 feature.

**Re-run 2026-10-15 closed both unknowns, and one of them is a design decision.**

`finish_event = no` is the expensive answer. `SOUNDKIT_FINISHED` fires for a SoundKit and does
not fire for a FileDataID, and **every sound this addon owns is a FileDataID**. Phase 4's
micro-sequencing engine therefore cannot be event-driven off `runFinishCallback`; it has to be
a timer holding a measured clip length. That is already the design the mock assumes
(`finishEventForFiles = false`, "unknown, assumed hostile"), so nothing built so far rests on
the answer that did not come - but the Phase 4 entry that calls `runFinishCallback` "the whole
sequencing engine" is now wrong and is corrected below.

`weather_model = yes` means a Model frame will load `Goblin_Weather_Machine_Rain.M2`. It does
NOT mean anything is visible: the check deliberately records that a loaded model is not a
rendered one, and nothing has been seen on screen.

**Still unanswered, and it needs a full client restart rather than a `/reload`:** which TOC
suffix this client loads. `build/make_flavour_probe.py` writes a `DuskfallFlavour` folder with
ten TOCs, each loading a different one-line Lua, so whichever line appears in
`DuskfallFlavourDB` names the suffix. It was installed while the client was running and WoW
only scans `Interface/AddOns` at launch, so it has not loaded yet. **Exit the client fully and
relaunch; no command needed.**

### Blizzard's own lightning, and what it does not give us — 2026-10-16

A [r/classicwow post](https://www.reddit.com/r/classicwow/comments/1x7k116/) showed real
lightning bolts with environment flashes on Forever. Checked both client binaries on disk:

| Thing | State |
|---|---|
| `C_Weather` | still exactly one function, `GetCurrentWeather`. No setter, as before |
| A lightning CVar | none |
| `CWeatherLightningManager`, `LightningRec_C` DB2, `"Start Weather Lightning ID %d"` | present in **both** `WowB.exe` and `_forever_/Wow.exe` |

So it is engine-side and server-driven: nothing new to call, and nothing that makes the
overlay redundant. **Not provable as new in this patch** - the 70374 binary was overwritten
by the update, so there is no before to diff against.

**Consequence:** during a real server storm our flash doubles with theirs. We already read
`GetCurrentWeather()` for the calib logger, so our lightning should stand down when the
client reports a storm. Not built yet.

**Two other things that fell out of the same look at the disk:**

- The beta is now **1.60.1.70425**. The probe results above are from **70374**, so they are
  one patch stale. Re-run `/dusk probe` before 21 Oct.
- **`_forever_` is installed** - product `wowf`, 1.60.1.70245, pulled 15 Oct, never launched
  (no `Interface/` or `WTF/` in it yet). That is the client that ships on 4 November, so the
  flavour probe belongs there rather than in `_classic_beta_`.

### Can we turn the realm's own weather off? — probe added 2026-10-16

Asked directly. There is no weather setter in Lua and there never was, but `weatherDensity`
is an ordinary graphics CVar (0-3) sitting in the binary between `particleDensity` and
`volumeFogLevel`, and at 0 the client renders no weather at all. The whole question is
whether an addon may write it, which only a live client can say.

`weather_cvar` added to `Duskfall/Probe.lua`. It writes a harmless control CVar first and
restores everything, because **a protected CVar does not raise**: `SetCVar` returns as
though it worked and the value simply does not move, so "it did not change" and "addons
cannot write CVars at all on this build" are the same observation without a control.

**The feature is deliberately not built yet.** Silently leaving a player's weather disabled
after logout is a one-star review, so it needs an opt-in toggle and a restore on logout -
worth designing once the answer is in, not before. Whether `weatherDensity 0` also stops the
new engine lightning is a question for the author's eyes, not for Lua.

## The visual-quality consult, 2026-10-16

Prompt: `consult-prompt-visual-quality.md`, run through `multi-review.py`. Gemini 2.5 Pro and
Groq GPT-OSS 120B answered; Grok returned 403, the xAI team is out of credits, so this is a
two-model consult and not a three-model one. Gemini's reply is **truncated mid-sentence** at
item 2 of its own list, because the caller passes `max_tokens=4096`. Everything below item 2
of Gemini is absent, not omitted.

**Both models independently produced the same top two**, which is the only part of a
two-model consult that carries weight: *fake depth first, then make the flash read as a bolt
in a place*. Beyond those two they diverge, and most of what they diverge on is wrong.

### Checked against the binary before believing any of it

Every API either model told us to call was grepped out of `WowB.exe`. Positive controls
(`GetPlayerFacing`, `SetGradient`, `SetMask`, `SetBlendMode`) are all present, so a zero here
is a result and not a broken method.

| API the consult told us to call | In the client | Consequence |
|---|---|---|
| `GetCameraPitch` | **absent** | Groq's whole parallax formula is unimplementable. Yaw only. |
| `SetGradientAlpha` | **absent** | Gemini's horizon-fog call does not exist on this build. Removed in 10.0; use `SetGradient`. |
| `CreateMaskTexture` / `AddMaskTexture` | present | Masks are real, but they are **MaskTexture objects**, not frames. `SetMask` takes a *file path*. Gemini's `rain_far:SetMask(gradient_frame)` would not have worked. |
| `GetCameraZoom` | present | The only camera scalar we actually get. Weak, but it is something. |
| `SetHorizTile` / `SetVertTile` / `SetDesaturated` / `SetTexelSnappingBias` | present | Available, unused so far. |

### What to build, in order

1. **Horizon-weighted alpha, then a near-layer radial mask.** Both models' number one, and
   the one that attacks the actual tell: the sheet is uniformly dense from top to bottom.
   `SetGradient` on each layer, vertical, plus a hand-generated radial mask TGA applied to
   `near` so there is a clear bubble around the player. No camera pitch, so the gradient is
   fixed in screen space rather than tied to the horizon line; that is a real limitation and
   it is still most of the gain.
2. **Parallax from `GetPlayerFacing()` alone.** Yaw changes shear the slant and nudge the
   horizontal scroll per layer at different rates. Groq's pitch term is deleted.
3. **Lightning as a located event.** Converged, and the highest-value item with the new
   engine bolts standing next to ours. An off-centre soft-glow quad with a random rotation,
   a two-stage leader/return-stroke envelope, a faint complementary darken afterwards, and a
   thunder delay that *encodes* distance (`delay = metres / 343`, volume falling with it)
   rather than being a free-running log-normal.
4. **Stand aside when the realm sends a real storm.** Groq argues blend at ~30%, and is
   right that full suppression makes the world feel emptier than before the addon. Our flash
   must suppress hard though, whatever the sheets do, because two unrelated lightning systems
   firing out of sync is worse than either alone.
5. **1024² for `near` and `snow-near` only.** Groq's arithmetic is wrong (doubling texels
   **halves** magnification, 2.42x to 1.21x, not to 1.4x; and a 1024 32-bit sheet is 4.2 MB,
   not 2 MB). The direction stands: `near` is the magnified layer, so it is the only one that
   gains. `far` is minified 0.70x and with no mipmaps it is the one that *shimmers*, which
   more texels makes worse, not better. Far stays 512.
6. **Lens drops and a ground-wet gradient.** Cheap, low risk, last. Ground wetness is a MOD
   gradient over the bottom band of the screen; the "ripple line" Groq describes is a
   2-pixel scrolling strip in screen space with no relation to where the ground actually is,
   and reads as a HUD artefact. Take the gradient, drop the ripple.

### Rejected, with the reason

- **`hooksecurefunc` into `CWeatherLightningManager`** (Groq). It is C++ with no Lua binding;
  there is nothing to hook. Correctly called a trap by Groq itself.
- **Groq's Model-frame section asserts we already proved particles are clipped.** We did not.
  We proved the M2 *loads*. The conclusion is invented, and treating it as settled would
  close an open question with a hallucination. Still open, still item 8 of Phase 1, still
  lowest value.
- **`SetRenderMode("BLEND")` and `model:PlayAnim(0)`** (Groq). `SetRenderMode` exists in the
  binary; `PlayAnim` does not appear and the pair is quoted as if it were a known recipe.
- **`playbackFlags = {ignoreMute = true}`** (Groq). Invented. There is no such field.
- **An intensity slider** (Groq, item 8). We already have presets and `/dusk density`. It is
  proposing a feature we shipped.
- **Per-frame costs quoted in milliseconds** (both). "1-2 ms per frame for two extra quads"
  is off by two orders of magnitude and would be a third of a 60 fps budget. Ignore every
  cost figure in both documents; the real numbers come from our own `OnUpdate` timing.

### What must not ship unseen

The client disappears 21 October. Of the list above, **1, 2 and 3 change what every player
sees on every frame** and none of them can be eyeballed after that date. They get built and
looked at before the 21st or they wait for the first post-launch patch. 5 and 6 are safe to
build blind: a texture swap is verifiable from the TGA itself, and a bottom-screen gradient
cannot fail in a way a spec will not catch.

### Phase 1 — by 21 October. 8 days. Client-gated and unrepeatable.

In priority order, because there may not be time for all seven. Mechanics are in
`### /rain calib` above; the logger is already built and committed.

**Seven of the eight are now one command.** `Duskfall/Probe.lua`, built 2026-10-14. Type
`/dusk probe` in game, `/reload` when it says to, then `/dusk probe report`. Every answer is
written to `DuskfallDB.probe` in `WTF/Account/<ACCOUNT>/SavedVariables/Duskfall.lua`, so the
results come off disk afterwards rather than being transcribed out of a chat window. Items 4
and 6 are the exceptions: 4 is travel the probe cannot do, and 6 is a folder-naming
experiment, not a Lua question.

Three things about it that are the whole point:

- **Negative results carry a positive control.** The mute check plays an *unmuted* file
  first; if the client refuses that, it records `unknown` and refuses to conclude. The finish
  check fires a known SoundKit first; a silent FileDataID next to a silent control proves
  nothing and is recorded as `unknown`, not `no`.
- **Proxies are not reported as the thing.** The client can only say it *agreed* to play.
  Whether sound came out is the player's ears, so the ambience check records `ask` and waits
  for `/dusk probe heard yes|no`.
- **It is a separate chunk, pcall'd per check.** A raise in the probe cannot abort
  `Duskfall.lua`, and one exploding check cannot cost the other six. Covered by
  `test/spec_probe.lua`; drop the file and its TOC line to ship without it.

It leaves the rain muted on purpose when it finishes, because the mute has to outlive the
session to be measured after a `/reload`. It says so.

1. **Does SavedVariables read back on build 70338?** First, because it gates both launch
   blockers. Set a value, `/reload`, read it back. If it fails, the options panel and the
   preset strings both die and the launch shape changes, so this answer is worth more than
   the other six combined.
2. **Play an ambience-channel sound with `Sound_EnableMusic` set to 0.** The single
   assumption the entire ambience-led strategy rests on. If ambience is silenced along with
   music, the product thesis needs rebuilding.
3. **Enumerate `C_Sound`.** Confirms on a live client what the re-probe already established
   in the binary: that these are declared params fields rather than adjacent strings. `volumeOverride` alone deletes the five
   pre-baked gain variants; `runFinishCallback` is the whole Phase 4 sequencing engine.
4. **`/rain calib on`, then travel.** Log real weather transitions across several zones and
   both indoor and outdoor states. Feeds the ambience map and the zone-to-biome table.
5. **Does `MuteSoundFile` survive a relog**, or must it be reapplied on `PLAYER_LOGIN`?
6. **Which TOC flavour suffix does this client load?** The two candidates are mutually
   exclusive and only one report cited any evidence. Getting it wrong means the addon does
   not load at all on 4 November.
7. **Does the Settings API host a panel at all on this build?** Added 2026-10-13 from the
   consult. `initializer:AddSearchTags()` is already known to throw `ADDON_ACTION_FORBIDDEN`
   here, which is evidence the settings registration path is partly broken on Forever. Push a
   stub panel through `Settings.RegisterCanvasLayoutCategory` and see whether it registers,
   opens, and survives being toggled in combat. Together with item 1 this decides whether a
   GUI is even possible, and it cannot be answered after the client is gone.
   **Downgraded 2026-10-14:** the settings window was built without the Settings API, so this no
   longer decides whether a GUI exists. It is now only worth knowing whether we could *also*
   list ourselves in the client's own addon settings as a second way in.
8. **Can a Model frame host a Blizzard weather M2?** Lowest value of the eight. Do it last,
   or drop it.

Also while the client is up, though these do **not** expire and so are not really Phase 1:
check the fullscreen quads at 21:9 and at several `UIParent:GetScale()` values, eyeball
`/dusk snow` and `/dusk blizzard` in daylight and at night (the whiteout cap and the snow
tint are both guesses until seen), and confirm the v2 code actually renders (the Blizzard FileDataIDs, the mist texture and the indoor fade
have never been seen working). Costs minutes now; the alternative is learning about it from a
one-star comment on 5 November.

### Phase 2 — 21 October to 4 November. 14 days. No client exists.

**The mock API is DONE, 2026-10-13.** It was the first thing and it is built: `test/`, run
with `lua test/run.lua`, **147 specs, all passing**, under Lua 5.1.5 built to `~/.local`
because that is WoW's own interpreter version and a 5.2+ construct that would fail in the
client has to fail here too. `test/README.md` has the detail. What it covers: boot and
SavedVariables defaults, the time-of-day grade, the three rain layers and their geometry,
the audio bed and its reloop, lightning, and the calibration logger.

The mock reproduces client *misbehaviour* rather than an idealised API, which is where its
value is: `RegisterEvent` on an unknown event raises, restricted getters can return a secret
value, `PlaySoundFile` can refuse a FileDataID, `GetBuildInfo` returns interface `16001`, and
hidden frames get no `OnUpdate`.

**It found one real bug on its first run** (fixed, `f0f6…`): the indoor poll lived on the
overlay's `OnUpdate`, and the overlay hides when it is not raining. Going indoors hid it,
hiding stopped the poll, and nothing could then notice the player walking back outside except
a `ZONE_CHANGED` event — and the unreliability of those events is the entire reason the poll
exists. The poll is now a `C_Timer` ticker, which runs either way. This is a bug Phase 1
would most likely not have caught: it needs a player to go inside, come out somewhere that
fires no zone event, and notice that the rain never came back.

Note for later: the mock will not invent a number it cannot measure. Sound durations are
supplied per spec rather than defaulted, so no test result rests on a fabricated length.

**Ships 4 November, because Phase 1 will have verified it:**

- ~~`AlwaysRain` → `Duskfall`~~ **DONE 2026-10-14.** Folder, file, TOC, frame names,
  globals and slash commands all renamed; `/dusk`, `/duskfall` and a permanent `/rain`;
  `gloom` subcommand is now `dim` with `gloom` kept as an unadvertised alias. Suite 53/53.
  Three specs added: the migration carries settings over exactly once, a non-table old
  profile is ignored rather than fatal, and `dim` and `gloom` both set the same value.

  **On the migration, and one thing the research round got right.** The old SavedVariables
  file is named after the *folder*, so it only loads if an addon named `AlwaysRain` is still
  installed. `## OptionalDeps: AlwaysRain` is in the TOC so that, where the old folder does
  exist, it loads first and the global is readable. **No stub folder is shipped**: the addon
  has never been published, so the only install in the world that can hit this path is
  the author's own, and shipping strangers a second folder for a migration that can never fire
  for them is noise on a CurseForge page.

  The copy is wrapped in a `pcall` and the loop is marked done with a `migrated` flag, so a
  stale `AlwaysRainDB` on disk cannot keep reverting later changes. **Stated honestly in the
  spec itself: on Lua 5.1 a plain table cannot make `pairs()` raise, so no test can reach
  that `pcall`.** It guards client-side weirdness the mock cannot reproduce. What is tested
  is the `type(...) == "table"` guard.
- **Ambience bed as a dumb zone-to-sound map**, with a **fallback FileDataID per track** in
  case a user's install lacks the file. The real scheduler is Phase 4; a user in week one
  cannot tell a zone-keyed loop from a sequenced one.
- **A first-run message on `PLAYER_LOGIN`**, once, for a fresh install only. Both models
  flagged that the plan had no onboarding at all: a stranger installs an atmosphere addon,
  sees weather they may think is Blizzard's, and never learns there is anything to configure.
  One line naming the addon and the slash command.
- Three good default presets, so it is worth something with zero configuration.

**Ships ~11 November as v1.1, written in Phase 2 but not shipped untested:**

- ~~**Options panel.** Gated on Phase 1 items 1 and 7.~~ **Built 2026-10-14, ahead of plan, and
  it is no longer gated on item 7** — it does not use the Settings API at all, which is what
  removed the dependency. See "The settings window" above. Item 1 (do SavedVariables read back
  on build 70338) still matters, but it now gates the whole addon equally rather than the panel
  specifically.
- **Preset sharing, downgraded.** A plain-text, human-readable config string, no compression
  and no base64. The sharing *mechanic* is what matters (the WeakAuras and wago.io precedent)
  and a readable `key=value;key=value` string gets nearly all of it for a fraction of the
  code. Compression can come later if strings ever get long.
- **Effects as data, not code**, which is the 2026-10-12 consult's unanimous #1 and is now
  correctly understood as an *enabler, not a blocker*. Each layer becomes
  `{ texture, blend, colour, alpha, scrollX, scrollY, parallax, mask }` plus an audio block
  and a trigger block. It makes snow a data entry and the panel a thin view over a table, but
  **the panel does not depend on it** — see the cut order.

**Publishing. Starts immediately, not on 21 October, and not in launch week:**

- GitHub repo, public, **MIT licence** (permissive so addon managers and forks are unblocked;
  `Weather`'s All Rights Reserved is a discovery cost for no gain).
- Release workflow pinned to `BigWigsMods/packager@v2.6.1`. v2.6.0 added Forever support in
  PR #202; v2.6.1 fixed a WoWInterface classic check.
- **CurseForge project submitted this week, with placeholder assets.** Revised from
  27 October. Gemini's point, and free: the page does not need the finished code or the final
  GIF, and submitting early starts a human approval queue that both models think takes longer
  than six days for a first-time author. Fill the page in afterwards. Hold a GitHub Releases
  link as the fallback if approval slips past 4 November.
- WoWInterface as the second channel.
- **One 10-second looping GIF** of rain plus the day-to-night transition. The whole marketing
  asset: CurseForge gallery, README, Reddit post, Discord post. Both models named a neglected
  project page as the anti-pattern that caps a first addon regardless of code quality. No
  YouTube edit before launch.

### Phase 3 — 4 November, then ~11 November.

**4 November:** tag `v1.0.0` with the verified subset. Post once to the Forever community
with the GIF. This is the one day the addon can be found without search ranking.

**~11 November:** tag `v1.1.0` with the panel and preset sharing, after a week of running
them on a live client. A second release a week after launch is also a second appearance in
the addon managers' "recently updated" lists, which is not nothing.

### Visual entropy — DONE 2026-10-15 (commit 2b9839e)

A constant scroll rate is the biggest tell that this is a 2D overlay: the eye finds the
loop inside a minute. Shipped: ONE Ornstein-Uhlenbeck gust signal (tau 7s, sigma 0.35)
with per-layer one-pole followers (near 6.0, far 2.2, mist 1.0 /s), driving scroll rate,
layer alpha, slant shear and gloom, scaled 0.45x at light to 2.0x at monsoon. `/dusk gust
0..2` plus a panel slider; 0 is exactly calm.

Design confirmed by two independent LLM consults (Gemini 2.5 Pro, GPT-OSS-120B), saved to
`~/code/eco/operator/reviews/review-{gemini,groq}-2026-10-15.md`. Both said: share one
signal rather than per-layer noise, lag the layers, keep modulation above a ~2% perceptual
floor, and do NOT modulate tiling density (reads as the camera zooming).

**Audio entropy is the matching item and is NOT done** — see Phase 4 item 1. Both consults
converged on co-prime bed lengths (e.g. 23s + 31s, which do not re-align for 713s) layered
2-3 deep, 10-15% crossfade overlap, per-play `volumeOverride` jitter of 5-8%, and
log-normal rather than Poisson intervals for one-shots so gusts cluster. 4+ simultaneous
beds turns to mush.

### Math audit — DONE 2026-10-16 (commit 42423f6)

Every formula in the addon was re-derived against its own comment. Four were wrong, none
had ever been reported, and no existing spec could have caught any of them, because every
spec until now asserted behaviour a player can name ("snow drifts") rather than that a
constant means what it says.

| Was wrong | Effect | Fix |
|---|---|---|
| Gust noise scaled `sqrt(3)` | every gust at 71% of its stated size; spread 0.46 not 0.65 | `NOISE_SCALE = sqrt(6)`: the driving noise is TWO uniforms, variance 2/12 |
| Scroll step not multiplied by tiling | fall speed silently divided by density; `speed` meant 0.59x to 2.76x what it said | `* tiling` in the offset step, and every preset's `speed` divided through by its own density, so the screen is pixel-identical |
| Thunder interval derived from fall speed | fixing the above would have taken a monsoon from a clap every 48s to every 15s | `strikeEvery` stated per preset, at the values the old formula produced |
| Lightning flash ignored `db.scale` and `IndoorFactor()` | a full-strength flash over rain drawn at a quarter | both applied to the peak |

Four smaller ones in the same pass: one-shot thunder bypassed the volume slider (new
`Play()` shared with `SlotPlay`), suppression was keyed on `db.enabled` rather than on
whether we are actually playing (so sound-off left the realm muted), `FlashOnce` built a
new frame per thunderclap and `CreateFrame` has no inverse, and `BedVolume` could exceed
1.0 after its jitter.

`test/spec_math.lua`, 10 specs: the rule is that if a number in the source is justified by
a sentence of maths, there is a spec that checks the sentence.

### Menus, wording and the icon — DONE 2026-10-16

Asked for directly: "more native to WoW", the wording, and an icon that is not generic.

- **Native chrome.** Blizzard's nine-sliced `UI-DialogBox-Border` and the carved
  `UI-DialogBox-Header` plate, around our own dark fill rather than the brown parchment
  that usually comes with them, plus `UIPanelCloseButton`. Gold title and headings. Both
  templates are probed with `pcall` and both fall back (four-quad border, an "x" button),
  because an unknown template name raises.
- **Title Case nouns**, with the plain-English sentence demoted to the tooltip, which
  already carries the slash command: "How visible it is" became **Visibility**, "How dark
  it gets" **Darkness**, "How much it gusts" **Wind**, "Volume: Ambience" **Channel:
  Ambience**.
- **Procedural minimap icon**, not a borrowed spell texture: a dusk-gradient sky masked
  round inside the brass ring, with six hand-scattered streaks that slant at the same 7.5
  degrees the sheets do, become dots for snow, and grey out when the weather is off. It
  repaints through the same `DuskfallAPI.changed` hook the window uses.

### Screenshot sweeps are a within-sweep ranking, not a calibration

Three sweeps on build 70374. Rain at normal measured -19.3% against its control at 12:13
and -7.6% at 12:23 with an **unchanged preset**, because the control scene itself differed
(mean luminance 69.9 vs 64.4). Only the ordering inside one sweep carries information.
Never compare a percentage across two sweeps, and never tune a preset off one.

The near layer is **ADD blend**, so a white snow sheet literally adds luminance and the
gloom underneath has to pay for it before it can darken anything. That is why snow kept
coming out brighter than no weather at all.

### Phase 4 — after launch, in this order.

1. **Micro-sequencing beds**, instead of looping one file. All three product reports
   independently named this as the one world-class feature, and it is where fifteen years of
   commercial ambient audio converged (myNoise's Animate, Noisli's oscillation).
   **Corrected 2026-10-15: it cannot be driven by `runFinishCallback`.** The live probe found
   `SOUNDKIT_FINISHED` fires for a SoundKit and not for a FileDataID, and every sound we own
   is a FileDataID. The sequencer is a `C_Timer` holding a measured clip length, which is what
   the test harness has assumed from the start. No longer gated on anything.
2. **Snow**, which is the same engine with a different sprite and a slower scroll with sine
   drift. First new weather type because it is nearly free once effects are data.
3. **Music as an opt-in mode**, routed so a `Sound_EnableMusic = 0` user is unaffected.
4. **Fog**, then **ash and embers** (snow with ADD blend and a warm tint).
5. Submerged fade using `IsSubmerged()`.

### How much development is actually left, and where

The honest shape, and the reason the product plan is what it is:

| Half | State | Work remaining, ever |
|---|---|---|
| **Visual** | **Essentially finished.** The ceiling is documented, hard and reached | ~2 weeks, total. Snow, fog and ash are data entries plus a generated texture once effects are data. There is no third act, because MOD blend over a 2D sheet is the last thing an addon can do to the screen |
| **Audio** | **Barely started.** A single looping rain bed | Months. The sequencing engine, a zone-biome-time map over Blizzard's entire library, bed mixing, crossfades, `MuteSoundFile` to remove what grates |

That asymmetry *is* the plan. The visual half bought the launch; it is finished and cannot
be extended. Everything after 11 November is audio, and the field is empty: nobody sequences
audio, FAME is music-only with zero ambience, and `runFinishCallback` and `volumeOverride`
are unexploited by anyone shipping today.

**What makes it defensible is context, not fidelity.** A browser tab of lo-fi has unlimited
content and zero setup, and will always beat us on both. It cannot know the player walked
into an inn at 2am in the rain. Every hour of Phase 4 should go into the engine knowing
*where and when you are*, not into making any single sound better.

**The honest ceiling.** This is a quiet atmosphere addon, not WeakAuras. Dynamic Weather took
years to reach 20.7k. The counter-evidence is that Forever-native *audio* addons move much
faster than that (Spoken Player: 97,856 in 24 days), which is the main reason the audio half
is the product rather than a feature of it. Low tens of thousands is a good outcome here;
anything framed around more than that is not supported by anything observed.

### The cut order, if the dates are at risk

Decided now, in the calm, so it is not decided at 2am on 3 November. Cut from the bottom:

1. WoWInterface as a second channel. CurseForge alone is fine.
2. Snow, fog, ash. Already Phase 4.
3. **The effects-as-data refactor.** Corrected 2026-10-13: the previous version claimed
   cutting this also cost the options panel, and **both consult models independently called
   that a rationalisation for doing a refactor the author wanted to do anyway.** They are
   right. A panel over hardcoded setters is ugly code and an identical experience, and it is
   a weekend rather than two weeks. The refactor is now independently droppable and the panel
   does not move with it.
4. Preset sharing, if the plain-text serialiser turns out to be more than a day. It is the
   growth mechanic, so it is the last feature cut rather than the first, but it is a feature
   and not the product.
5. **Nothing below this line gets cut.** The rename, the ambience bed, the first-run message,
   the GIF, the CurseForge submission, and the options panel in v1.1. Shipping without any
   one of these is not a reduced launch, it is a launch that cannot be found or configured.

### The biggest risk, corrected

The previous version named Phase 1 not happening. **Both consult models said that was wrong,
and that the real risk is shipping 14 days of never-executed code to strangers on a day it
cannot be hotfixed.** They are right, and the fix is the mock API plus the split launch
above. **The mock half is now built and green**, so the remaining exposure is the part it
cannot reach: everything in `## Open / unverified`, which needs the client.

Phase 1 is still the hard deadline, because it expires and nothing else does. But it is a
deadline, not the risk. The risk was the thing the plan was comfortable about.

## The distribution consult, 2026-10-13

Gemini 2.5 Pro and GPT-OSS-120B on distribution, the name and the phase ordering. Saved to
`code/eco/operator/reviews/review-{gemini,groq}-2026-10-13.md`. **This is a two-model
consult, not a four:** Grok returned 403 out of credits and Claude Opus timed out at 362s.
Two models agreeing is a weaker signal than four and the conclusions below are weighted
accordingly.

### The one thing that changes the plan: the options panel is a launch blocker

Both models, unprompted, moved it from conditional to required, and both volunteered the
same reason: someone who installs an addon called *Cozy* is not a power user, finds no
settings window, and uninstalls inside two minutes. Both also proposed paying for it the
same way, by shipping the ambience bed as a dumb zone-to-sound map and deferring the real
scheduler.

Taking it. The consequence is that **Phase 1 item 6, whether SavedVariables reads back on
build 70338, is now the highest-value check in the whole phase** rather than one of seven.
A panel that cannot persist a setting is worse than no panel, and that answer only exists
while the beta client is up.

### The genuinely new idea: shareable presets are the virality mechanic

Gemini's strongest point, and nothing in six prior reports raised it. The claim is that
Skyrim ENB presets and Minecraft shaderpacks (BSL, SEUS) spread because users shared
*configurations*, not merely because they looked good, and that an addon configurable only
by slash commands has nothing to share however well it renders.

This holds, and the proof is inside WoW rather than outside it: **WeakAuras** is the
most-installed addon in the game's history and its growth mechanism is wago.io import
strings. The addon is the player, the content is other people's strings.

So an import/export preset string is not a nice-to-have, it is the only mechanic by which
this product can spread without an audience. It is also cheap: serialise the config table,
compress, base64. It needs working SavedVariables, which is the same gate as the panel, and
it belongs in the launch build.

### Where the consult was wrong, and ignored

- GPT-OSS-120B wanted the name changed to **Azeroth Mist**, citing that "cozy" reads as
  pejorative in "62% of recent Forever forum threads". It has no browsing and cannot have
  measured that; the number is fabricated and was discarded. The recommendation fails on its
  own merits regardless: *Mist* re-caps the product at one weather type, which is the exact
  trap `AlwaysRain` is being renamed to escape. **The name stands.**
- The same model claimed the beta client "will stop loading `## OptionalDeps:` entries after
  21 October". That is not a thing. The client is withdrawn, not degraded.
- It also wanted the folder to carry the keywords. That loses the one property the folder
  has, which is that it is the only expensive name to change, so it should be the stable one.

### Accepted with a correction

Gemini proposed a Phase 1 check for ultrawide aspect ratios and `UIParent:GetScale()`
against the fullscreen quads. **It does not expire with the beta** — a resolution and UI
scale can be changed on any client at any time, so this is not a Phase 1 item by the
ordering principle. It is still worth doing now, because it costs minutes while the client
is up and the alternative is learning about it from a one-star comment on 5 November.

### Distribution, where the two split and what to do

One said a 10-second loop GIF on the main WoW subreddit on launch day; the other a
30-second before/after YouTube video embedded on the CurseForge page plus a post in the
Forever Discord the day before. Both flagged the same anti-pattern, which is the part worth
keeping: **a neglected CurseForge page with no media caps a project regardless of what the
code does**, because the decision to install happens in seconds on the preview image.

The resolution is that these are one asset, not two strategies. Make a single 10-second
looping GIF of the rain and the day-to-night transition. It goes on the CurseForge page, in
the README, in the Reddit post and in the Discord post. A 30-second YouTube edit is more
work for less reach and is not worth making before launch.

## Engineering reference — what to build, and what is impossible

Not a schedule. `## THE ROADMAP` above is the only schedule; this is the technical backing
for the items in it, from a 2026-10-12 consult of Gemini 2.5 Pro and GPT-OSS-120B (saved
under `code/eco/operator/reviews/review-{gemini,groq}-2026-10-12.md`). **Every API either
model assumed was checked against the binary before being written down here** — see the
corrections at the end, two of them were invented.

Its three top recommendations have all moved into the roadmap: effects-as-data is the Phase 2
enabler, the options panel is a Phase 2 launch blocker, and the 5-7 preset library is the
first thing in the cut order.

### Effects worth building, ranked

| Effect | Verdict |
|---|---|
| Snow | same engine, different sprite and slower scroll with sine drift. Do first. |
| Overcast / colour grading | already have the machinery; cheapest mood per line of code |
| Fog | scrolling noise; convincing despite having no depth |
| Ash / embers | snow with ADD blend and a warm tint |
| Sandstorm | fast streaky scroll; weaker because real ones occlude distance and we cannot |
| Falling leaves / blossom | needs `SetRotation` per drop and real art effort |
| Heat haze | **both models overrated this.** A true shimmer is refraction, which needs to sample the scene. We cannot. It would read as a watery smear. |
| Bloom | impossible — requires reading scene brightness |

### Screen-space tricks

- **Horizon fade** (Gemini's best idea, now built): fade the bottom of each rain layer so drops
  do not run down over the player's feet and the action bars.
- **Speed response** (now built): `GetUnitSpeed("player")` drives fall rate, so running into
  rain makes it fall harder.
- **Submerged**: `IsSubmerged()` exists — fade everything out underwater. Not built.
- **Three parallax layers instead of two**, with size, alpha and scroll rate all keyed to depth.
- **Follow the server's real weather** when it sends some: `C_Weather.GetCurrentWeather()` is
  readable, so the addon can at least match intensity rather than fight it.

### Where they disagreed

Gemini said cut the camera-turn parallax as a subtle effect with a permanent per-frame cost;
Groq said extend it. Keeping it — it is a few lines in an `OnUpdate` that already runs, and it
is the main thing selling the curtain as having depth.

### Corrections to their advice

- `GetCameraPitch()` (Gemini) **does not exist**. No camera pitch is exposed; `GetPlayerFacing()`
  is the only orientation available, and it is the player, not the camera.
- `C_Weather.GetWeatherInfo()` (Groq) **does not exist**. Only `GetCurrentWeather()`.
- Groq proposed faking heat haze by copying `WorldFrame` into a texture and distorting it.
  Addons cannot sample the rendered scene; there is no such copy.
- Groq's "merge the mist into the far-rain texture to save memory" is a false economy: four
  512×512 quads is nothing, and mist has to scroll at its own rate to read as distance.
- Both quoted invented FileDataIDs for the rain audio. The verified ones are in the table above.

## Open / unverified

- **v2 has not been seen running *in the client*.** It now runs green under the mock
  (`lua test/run.lua`, 116 specs), which settles the logic but not the rendering: the Blizzard
  FileDataIDs, the mist texture, the blend modes and the horizon fade are all still
  unconfirmed against real hardware. `/rain status` reports `(bundled audio)` if the sound IDs
  were refused. **A green suite is not a working addon** — the mock records what was asked of
  the renderer, and has no opinion on what came back.
- `IsIndoors()` is the client's own notion of inside and it is imperfect — it reads true under
  some large awnings and false in some open-roofed buildings. Nothing better is exposed.
- Dungeons and raids are not specially handled; they report indoors, so the rain stops there.
- `## Interface: 16001` is inferred from `SET engineSurveyPatch "16001"` in Config.wtf.
- ~~**`weatherDensity` is still `"0"`.**~~ **Superseded 2026-10-20:** the probe read it as
  **3**, and Blizzard's own rain was seen falling in Elwynn the same session. The
  side-by-side this bullet asked for exists now; see the deference section at the top.
- Yaw parallax uses `GetPlayerFacing()`, which is the player, not the camera. Free-look
  (right-mouse held) moves the camera without moving facing, so the rain will not sweep then.
- the author's beta client runs very low graphics (`RenderScale 0.65`, particles off). The overlay is
  4 fullscreen quads plus one `OnUpdate`, so cost is negligible, but in-client weather
  (`weatherDensity 3`, `particulatesEnabled 1`) is not free on a GTX 1660.
