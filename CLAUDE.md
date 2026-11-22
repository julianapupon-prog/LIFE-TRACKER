# life log

My personal life tracker. One HTML page (`index.html`), no build step, no framework. It started as a Claude artifact and I'm moving it to Claude Code so I can keep improving it. It's now a little Tamagotchi-style game: a pixel bunny grows and gets happier when I actually do the things I track.

Start by reading `index.html`. The app works as-is. Don't rebuild it from scratch; change it piece by piece.

## What it's for

I want to stop planning and start doing. The app helps me keep up with my goals and see what I'm actually doing. It's not meant to be another productivity system. Keep it simple, quick to use on my phone, and pretty.

## Files

- `index.html`: the whole app (HTML + CSS + JS in one file)
- `data.json`: a copy of my data at the time of the move (also embedded in `index.html`, see "Data")
- `CLAUDE.md`: this file
- `supabase/setup.sql`: the database for friends (run once in the Supabase SQL editor; safe to re-run).
- `manifest.webmanifest`, `sw.js`, `icons/`: make it installable on the phone (PWA) and work offline. The icon is the pixel bunny (made from the same sprite) on pink. `sw.js` loads the page network-first, so changes show up right away. Bump `CACHE` in `sw.js` if the icons change.

## Design rules (keep these)

- **Look:** cute pixel-art game, pastel and colourful. References: pixel virtual-pet apps, cosy top-down farming/life games, soft pixel meadows, pastel handheld consoles. Original art only (no copying real games or consoles, no "Game Boy" branding).
- **Colours:** cream `#FFF4EC` background with a faint pink grid, paper `#FFFDF9` cards, dark plum `#4A2B4F` for text, outlines and hard shadows. Accents: pink `#F7A8C4` / hot pink `#E86A9A`, sky `#9FD8F5`, mint `#A8E6C1`, butter `#FFE38A`, lavender `#E2CDF2`. All defined as CSS variables in `:root`.
- **Shapes:** square corners, thick plum borders (2–3px), hard offset shadows (no blur), segmented pixel bars.
- **Fonts (Google Fonts):** **Pixelify Sans** for everything readable (body, headings, buttons; it has Cyrillic). **Silkscreen** for tiny all-caps labels, the bunny's speech bubble and the console text.
- **No photos** in the design itself. The only images are book and film covers I upload myself.
- **Language:** the whole app is in English. The Russian tab can mix English with Russian examples.
- Mobile first: I use it on my phone. Inputs are at least 16px so iOS doesn't zoom.

## Tabs and features

Tabs live at the top, and the URL hash remembers the tab (`#home` (default), `#fitness`, `#sleep`, `#reading`, `#screen`, `#substack`, `#russian`).

0. **Home: the pet + her world**
   - A pastel pixel handheld console. The screen is `<canvas id="world">`. Most of the time it shows **the world**: a top-down tile map (`buildMap`, 48×36 tiles of 16px, view 160×120, camera follows her). Painted once to an offscreen canvas (`paintMap`, repaint with `W.dirty=true`), dynamic things are drawn on top every frame (`drawWorld`).
   - **Places:** my house + farm (8 plots) top-left; a street of 4 friend houses (one per friend, roof in her colour, name on top); a river with bridges; the town plaza (shop, notice board, fountain, benches); the shared garden (fenced, a pot per friend, ball); a lake with a dock (fishing, ducks); a forest (east) and a flower meadow (south-west). Real time of day (night 22:00–7:00: dark, lit windows, fireflies, she sleeps) and a daily weather from `weatherFor(date)` (rain waters crops).
   - **Moving:** hold the d-pad (or arrow keys), or tap anywhere to walk there (BFS path in `findPath`). Tapping a thing walks to it and uses it. A (pink, "use") uses what's next to her or pets her; B talks. Walking into a door enters: my house / a friend's house → side-view interiors (`in` / `visitIn`, the old 240×180 scenes with the bookshelf and TV), the shop door opens the shop.
   - Console pills: **map** (overview with places + live friends; tap to travel), **home**, **bag**.
   - Pets are 16×21 text-grid sprites in `SPECIES` (bunny / kitty / puppy), drawn at 1× in the world and bigger inside. `grid(kind,stage,species,wear)` makes faces (idle/happy/sad/sleep), bow (kid), scarf (grown), and clothes (`HATS`, glasses).
   - Customise in "your pet" (tap her name): name, animal, fur colour (`COLORS`), roof colour (`ROOFS`).
   - **Stats** (`petStats`, computed from real data, nothing stored): health (workouts), joy (finished books & films), smart (Russian), ideas (Substack notes), rest (sleep). Points fade 18%/day; never below 8; she's sad when the average < 30. XP = all points; level every 20; baby → kid (60) → grown (250). Hidden tabs drop their stat.
   - **Game economy** (`S.game`): logging real things pays out once each (`claimRewards`): workout 3 water + 5 coins, finished book 15 coins + 2 seeds, film 8 coins + seed, each Russian toggle 1 water + 3 coins, Russian topic 1 coin, note 5 coins + seed (published +20 + seed), sleep 2 water + 3 coins (+ seed for 7–9.5h). Starter pack on first run; existing data doesn't pay retroactively.
   - **Farm:** 6 crops in `CROPS` (seed price, days, sell price). Plant from the bag of seeds, water once a day (costs 1 water; rain counts), grows one stage per watered day, harvest → items. **Forage:** 12 daily spawns in forest/meadow/lake shore (`forageToday`). **Fishing:** at the dock, 6 casts a day; tap/A when the "!" shows. Items can be fed to her (bag) or sold (shop).
   - **Shop:** seeds, clothes (`WEARS`), furniture (`FURN`: rug, plant, lamp, poster to buy; armchair / yoga mat / matryoshka / typewriter unlocked by milestones). Furniture shows in my interior.
   - **Missions:** 2 a day (`todaysMissions`): one real-life (from shown tabs) + one game task, +10 coins + seed each. Shown on home ("today") and the town board. **This week** card + the mailbox letter summarise the last 7 days.
   - She celebrates when I come back after logging (`lifelog-petxp` in localStorage), with the rewards in the bubble.
   - **Friends:** see the Friends bullets below; in the world, friends who aren't online hang out in the garden; online friends walk around live.
   - `window.__ll` exposes `P`, `W`, `G()`, `S()` for debugging and tests.

   - **Shared plant:** each pair of friends has a pot in the garden. Each of you can water it once a day; it grows one step (7 stages) on each day you *both* watered it (`water_plant` on the server).
   - **Friends** (card on home): each device gets a code like `LL-7K2QX` plus a secret (`S.social`, also in backups). Add by code (both ways). The card shows her pet, level, stats, "● playing now" or last active, this week's **challenge together** (`CHALLENGES`, picked per week, progress from both; +30 coins + 2 seeds when both finish), **book club** (books marked "book club" in reading are shared by title; same book = bonus), gifts (heart / carrot / flower), and "visit her house" / "go see her".
   - Shared with friends: pet info + `home` (roof, finished counts, this week's counts, hidden tabs, book-club titles, clothes, furniture). Never notes, workouts, reviews or other titles.
   - **Live:** Supabase Realtime broadcast (supabase-js loaded from jsdelivr only when friends are on), one channel per pair of friends. Each side sends its position ~5×/s while moving; positions on someone's own plot are re-mapped to that friend's house slot (`myArea` / `placePeer`). Emotes (hearts, hi) are broadcast too.
   - Supabase: RPC functions in `supabase/setup.sql` (tables locked; every function checks the secret). URL + publishable key in `SUPA` in `index.html` (meant to be public). `localStorage` key `lifelog-supa` overrides them for testing.

1. **Sleep**
   - Log a night: woke-up date, bed time, wake time, notes. Last night, 7-day average, bars for the last 7 nights, list (tap to edit).

1. **Fitness**
   - "me" card: height, starting weight, goal weight, my goals (text)
   - Training plan: a list of workouts (name + exercises, one per line). **I still need to add my real training.**
   - Check in: date, workout (picked from the plan or "other"), what I did, weight (optional), notes
   - Stats: workouts in the last 7 days, this month, total. Weight line chart once there are 2+ weights.
   - History of check-ins, tap to edit or delete

2. **Reading**
   - Three lists: reading now / wishlist / finished
   - Each book: title, author, optional cover photo (resized in the browser), status
   - When finished: date, 1–5 stars, review
   - "Read in [year] · just for fun" counter toward a goal (default 50, editable). It's not a serious goal.

3. **Movies & TV**
   - Same as reading: watching / watchlist / watched, type (film, series, documentary, other), where I watched it, cover, stars, review
   - Counter toward 70, also just for fun

4. **Substack** (my newsletter is called *afterimage*: books, art and film essays, in English)
   - Notes app for essay ideas: title, status (idea / drafting / published), body, links (one per line, `label | url`), tags
   - Search and filter by status

5. **Русский** (Russian study, A1 → A2)
   - Today: three toggles: studied / read a text / watched a video
   - Streak, study days this month, topics learned
   - Month calendar: darker = more done that day; tap a day to edit it (plus an optional note)
   - 253 topics in English with Russian examples, grouped as vocabulary / grammar / communication, then by theme. Each has a checkbox; some are tagged A2. A1 and A2 progress bars; filters: all / A1 / A2 / to learn.
   - Topic ids are `groupIndex.itemIndex` (by position in the `RU` array). **If you reorder or insert topics, migrate `ru.done`** or my ticks will move to the wrong topics. Adding at the end of a group is safe.

## Data

The state is one object:

```
{ v, updated,
  fitness: { height, weight, goalWeight, goals, plan:[{id,name,items}], checkins:[{id,date,workout,did,weight,notes}] },
  books:  [{id,title,author,cover,status:'reading'|'wish'|'done',finish,rating,review,added,club}],
  shows:  [{id,title,kind,where,cover,status:'watching'|'wish'|'done',finish,rating,review,added}],
  notes:  [{id,title,status,body,links,tags,created,updated}],
  ru: { done:{topicId:dateLearned}, days:{'YYYY-MM-DD':{s,r,v,note}} },
  goals: { books, shows },
  pet: { name, born, color, species, roof },
  social: { code, secret },
  prefs: { hidden: [tab ids] },
  sleep: [{id,date,bed,wake,notes}],
  game: { init, coins, water, seeds:{crop:n}, inv:{item:n}, crops:{plot:{k,planted,w:[dates]}}, claimed:{rewardKey:1}, picked:{date:[ids]}, casts:{d,n}, owned:{wear:1}, wear:{head,face}, furn:{item:1}, wateredOn, caughtOn, gardenOn } }
```

How it saves right now:
- The state is embedded in the page as `<script type="application/json" id="state">`.
- On claude.ai, the page saved itself by republishing its own HTML through `claude.use("artifact")`, and uploaded covers through `claude.use("assets")`. **These only exist on claude.ai.**
- Outside claude.ai those calls are absent, so the app automatically falls back to `localStorage` (key `lifelog-v1`), and covers are stored as small data URLs. That means data lives in one browser on one device only.
- **Settings** (link in the header): show/hide tabs (`prefs.hidden`). A hidden tab also drops its pet stat (`STAT_TABS`) and its "i just…" button, so the pet isn't sad about things you don't track; nothing is deleted. If Russian is hidden, the garden flowers count workout days instead.
- **Backup** (in settings): downloads the whole state as `lifelog-YYYY-MM-DD.json` (on a phone it opens the share sheet), and can load one back. Loading shows a summary and asks before replacing everything. The last backup date is in `localStorage` key `lifelog-lastbackup`.

## What I'd like next (ask me before doing big changes)

- Reminders: a daily push notification from the pet (needs a small server, e.g. a Supabase Edge Function + scheduled job)
- Sync my data across phone and laptop (Supabase is already set up)
- More garden activities with friends (seesaw, picnic), more places to explore
- Add my training plan to the fitness tab once I send it
- Keep it light: no heavy frameworks unless there's a real reason

## How I like to work

- Be direct and objective, short explanations
- Don't make creative or design decisions that change the look without asking
- Write in a natural, casual tone
