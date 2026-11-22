# life log

My personal life tracker. One HTML page (`index.html`), no build step, no framework. It started as a Claude artifact and I'm moving it to Claude Code so I can keep improving it.

Start by reading `index.html`. The app works as-is. Don't rebuild it from scratch; change it piece by piece.

## What it's for

I want to stop planning and start doing. The app helps me keep up with my goals and see what I'm actually doing. It's not meant to be another productivity system. Keep it simple, quick to use on my phone, and pretty.

## Files

- `index.html`: the whole app (HTML + CSS + JS in one file)
- `data.json`: a copy of my data at the time of the move (also embedded in `index.html`, see "Data")
- `CLAUDE.md`: this file

## Design rules (keep these)

- **Colours:** beige and royal blue only. Beige `#EBE4D1` (background), paper `#F4EFE1` (cards), royal blue `#1F3FBF`, dark ink `#132a85`. Thin blue lines and borders, a bit like an editorial grid.
- **No photos** in the design itself. The only images are book and film covers I upload myself.
- **Fonts:**
  - Ballpoint handwriting, **Nothing You Could Do**, ONLY for titles and highlights: app title, section headings, tab names, book and film titles, main buttons, big numbers.
  - Everything else uses a regular serif, **EB Garamond**.
  - Tiny labels use **Cormorant Garamond** in small spaced caps.
  - All from Google Fonts.
- **Language:** the whole app is in English. The Russian tab can mix English with Russian examples.
- Mobile first: I use it on my phone. Inputs are at least 16px so iOS doesn't zoom.
- Inspiration: blue engraved / toile-style illustration on white, and minimal editorial brand identity on eggshell with Egyptian blue. Elegant, calm, a bit literary.

## Tabs and features

Tabs live at the top, and the URL hash remembers the tab (`#fitness`, `#reading`, `#screen`, `#substack`, `#russian`).

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
  goals: { books, shows } }
```

How it saves right now:
- The state is embedded in the page as `<script type="application/json" id="state">`.
- On claude.ai, the page saved itself by republishing its own HTML through `claude.use("artifact")`, and uploaded covers through `claude.use("assets")`. **These only exist on claude.ai.**
- Outside claude.ai those calls are absent, so the app automatically falls back to `localStorage` (key `lifelog-v1`), and covers are stored as small data URLs. That means data lives in one browser on one device only.

## What I'd like next (suggestions, ask me before doing big changes)

- Real persistence that works across my phone and laptop (e.g. a small backend, Supabase/Firebase, or at least export/import of `data.json`)
- Make it installable on my phone (PWA: manifest + my own app icon in beige and blue)
- Add my training plan to the fitness tab once I send it
- Keep it light: no heavy frameworks unless there's a real reason

## How I like to work

- Be direct and objective, short explanations
- Don't make creative or design decisions that change the look without asking
- Write in a natural, casual tone
