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

- **Look:** cute pixel-art game, pastel and colourful. References: pixel virtual-pet apps, soft pixel meadows, pastel handheld consoles. Original art only (no copying real games or consoles, no "Game Boy" branding).
- **Colours:** cream `#FFF4EC` background with a faint pink grid, paper `#FFFDF9` cards, dark plum `#4A2B4F` for text, outlines and hard shadows. Accents: pink `#F7A8C4` / hot pink `#E86A9A`, sky `#9FD8F5`, mint `#A8E6C1`, butter `#FFE38A`, lavender `#E2CDF2`. All defined as CSS variables in `:root`.
- **Shapes:** square corners, thick plum borders (2–3px), hard offset shadows (no blur), segmented pixel bars.
- **Fonts (Google Fonts):** **Pixelify Sans** for everything readable (body, headings, buttons; it has Cyrillic). **Silkscreen** for tiny all-caps labels, the bunny's speech bubble and the console text.
- **No photos** in the design itself. The only images are book and film covers I upload myself.
- **Language:** the whole app is in English. The Russian tab can mix English with Russian examples.
- Mobile first: I use it on my phone. Inputs are at least 16px so iOS doesn't zoom.

## Tabs and features

Tabs live at the top, and the URL hash remembers the tab (`#home` (default), `#fitness`, `#reading`, `#screen`, `#substack`, `#russian`).

0. **Home (the pet)**
   - A pastel pixel handheld console. The screen is a `<canvas id="world">` (240×180 logical pixels): sky, mountains, house, tree, grass. Real time of day: from 22:00 to 7:00 it's night and she sleeps (any button wakes her for a bit).
   - Customise in the "your pet" sheet (tap her name): name, animal (bunny / kitty / puppy), fur colour (9 options in `COLORS`), house roof colour (`ROOFS`). Sprites are text grids in `SPECIES`; all three share the same body rows and eye rows so the faces, bow and scarf work for every animal.
   - **Scenes** (`P.scene`), switched by tapping things in the world or the home / inside / garden pills on the console, with an iris transition:
     - `out`: outside her house. Tap the house to go in, the signpost to go to the garden.
     - `in`: inside. Bookshelf with a spine per finished book (tap = list of finished books), TV rack with a case per finished film/show (tap = list), bed (nap), door (back out).
     - `garden`: the shared garden. Friends' pets wander here; swing, bench, pond, a ball you kick to each other, and one shared plant pot per friend (see Friends).
     - `visit` / `visitIn`: a friend's house, outside and inside, with her roof colour and her pet. Her shelf and TV show counts only.
   - Tapping the world uses hotspots registered while drawing (`P.hot`); anything else pets her.
   - Controls: d-pad left/right walks, up jumps, down sits. A (pink) or tapping the screen = pet her (hearts). B (blue) = talk (a tip based on her lowest stat). Tap her name to rename.
   - Four stats, computed from my real data in `petStats()`, nothing stored: **health** (workouts), **joy** (finished books & films), **smart** (Russian days + topics), **ideas** (Substack notes). Each logged thing gives points that fade by 18% per day, so stats drop if I stop. Gentle: stats never go below 8, she never gets sick or dies, she just gets sad (short ears) when the average is under 30.
   - XP = all points ever. Level every 20 xp. Grows from **baby** → **kid** (60 xp, gets a bow, bigger) → **grown** (250 xp, pink scarf, biggest).
   - World reflects progress: a flower per Russian study day this month, a stack of books by the door for books finished this year.
   - When I come back to home after logging something, she celebrates (hearts + "+xp" bubble, or "i grew up!"). Last-seen xp is in `localStorage` key `lifelog-petxp`.
   - "i just…" quick buttons open the existing forms: worked out, studied russian, finished a book, watched something, had an essay idea.
   - Sprites are text grids (`BUN`, `HEART`, `ZED`) with the `PAL` colours; `grid(kind,stage)` makes the sleep / happy / sad faces and adds the bow and scarf.

   - **Shared plant:** each pair of friends has a pot in the garden. Each of you can water it once a day; it grows one step (seed → sprout → … → little tree, 7 stages) on each day you *both* watered it. Server side in `water_plant`.
   - **Friends** (card on home): each device gets a code like `LL-7K2QX` plus a secret (`S.social`, also in backups). Add a friend by code (works both ways), see her bunny, level, stats and when she was last active, send a heart / carrot / flower (shows up on the other's ground for 3 days and she celebrates), and "invite over" (her pet visits your world for 90 seconds; only on your screen), and "visit her house". Only pet info is shared, plus counts of finished books/films and her roof colour (`home`), never titles. Only pet info is shared, never books, notes or workouts.
   - Friends use Supabase through the RPC functions in `supabase/setup.sql` (tables are locked; every function checks the secret). The project URL and publishable key go in `SUPA` in `index.html` (they're meant to be public). Until they're set, the card says friends aren't connected. `localStorage` key `lifelog-supa` can override them for testing.

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
  books:  [{id,title,author,cover,status:'reading'|'wish'|'done',finish,rating,review,added}],
  shows:  [{id,title,kind,where,cover,status:'watching'|'wish'|'done',finish,rating,review,added}],
  notes:  [{id,title,status,body,links,tags,created,updated}],
  ru: { done:{topicId:dateLearned}, days:{'YYYY-MM-DD':{s,r,v,note}} },
  goals: { books, shows },
  pet: { name, born, color, species, roof },
  social: { code, secret } }
```

How it saves right now:
- The state is embedded in the page as `<script type="application/json" id="state">`.
- On claude.ai, the page saved itself by republishing its own HTML through `claude.use("artifact")`, and uploaded covers through `claude.use("assets")`. **These only exist on claude.ai.**
- Outside claude.ai those calls are absent, so the app automatically falls back to `localStorage` (key `lifelog-v1`), and covers are stored as small data URLs. That means data lives in one browser on one device only.
- **Backup:** the "backup" link in the header downloads the whole state as `lifelog-YYYY-MM-DD.json` (on a phone it opens the share sheet), and can load one back. Loading shows a summary and asks before replacing everything. The last backup date is in `localStorage` key `lifelog-lastbackup`.

## What I'd like next (suggestions, ask me before doing big changes)

- Real persistence that works across my phone and laptop (e.g. a small backend, Supabase/Firebase, or at least export/import of `data.json`)
- Make it installable on my phone (PWA: manifest + my own app icon in beige and blue)
- Add my training plan to the fitness tab once I send it
- Keep it light: no heavy frameworks unless there's a real reason

## How I like to work

- Be direct and objective, short explanations
- Don't make creative or design decisions that change the look without asking
- Write in a natural, casual tone
