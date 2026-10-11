# Old People's Toolkit

Tools for old people with responsibilities and sore bones: automated quiet
hours, a stretch reminder, a "where was I?" message at start, bedtime, and a
clock with an alarm.

No gameplay changes. Just the grown-up stuff around playing.

Made for WoW: Forever.

## The tools

### 🎧 Quiet hours
- At night (23:00 to 07:00 by default) the game's volume goes down, so you
  don't wake the house, and back up in the morning.
- Change the volume yourself and it leaves your choice alone.
- You wear **Earmuffs** (Horde or Alliance ones) while it's quiet. Right-click
  them to skip quiet hours for tonight.

### 🧘 Old People's Stretch
- After an hour of playing (or whatever you pick, from 15 minutes to 3 hours), a pop-up asks you to stand up and get those old bones moving.
- "Remind me in 5 min", or "I stood up and stretched" (greyed out for a few
  seconds, so you actually stretch first).
- Never during a fight. Logging out for 10 minutes or more counts as a break.
- You start out **Fresh as a Daisy**, earn **Spring in Your Step** by stretching,
  and get **Stiff Joints** when it's time to stretch again.

### 🧭 Where was I?
- Log in after a while away (8 hours by default) and a window tells you when
  and where you last played, and which quests you were busy with.
- Had to stop in a hurry? It also shows what your bags were filling up with in
  your last half hour, like the boar meat you were farming or the bandages you
  were making. Closed up shop properly? Then there's nothing to remind you of.
- Fully automatic: it follows the quests you accepted or made progress on, and
  what you looted, gathered or crafted. Nothing to write down. Per character.

### 😴 Bedtime
- On work nights (Sunday to Thursday, or every night if you like): a heads-up
  15 minutes before your bedtime, and *"It's past your bedtime!"* when it's time.
- **Past Your Bedtime** sits with your debuffs until morning.

### 🕰️ Clock and alarm
- A bigger clock with your real (local) time. Drag it anywhere, scroll to resize.
  It replaces Blizzard's small minimap clock while it's showing.
- Click the clock to fold out the alarm. Type `15`, `1h30`, `22:30` or `10pm`
  for "I've got 15 minutes" or "I can play until 22:30".
- A heads-up 5 minutes before, and at the end: *"Time's up! I must go, my people need me!"*
- While it runs, **Responsibilities** sits with your debuffs and counts down.

## The pretend buffs and debuffs

Addons can't give your character real buffs, so these are icons that look like
them, lined up at the end of your buff and debuff rows. Hover for details,
right-click to act on them. Each one can be turned off in the options, and you
can pick your own icons (names from [wowhead.com/icons](https://www.wowhead.com/icons)).

## Options

Esc > Options > AddOns > Old People's Toolkit, or click the pocket watch on the
minimap, or type `/oldperson`.

## Commands

`/oldperson` (or `/opt`) opens the options. `/oldperson help` lists the commands.
Settings live in the options; commands are for doing things.

| Command | What it does |
|---|---|
| `/oldperson stretch test` | show the stretch pop-up now |
| `/oldperson stretch done` | I stood up and stretched: start the timer over |
| `/oldperson alarm 15` | alarm in 15 minutes (or `1h30`) |
| `/oldperson alarm 22:30` | alarm at 22:30 (or `10pm`) |
| `/oldperson alarm off` | clear the alarm |
| `/oldperson bedtime 23:30` | set your bedtime |
| `/oldperson whereami` | where you are, your quests, and what your bags are filling up with |
| `/oldperson whereami test` | the welcome-back window, as if you'd been away 3 days |
| `/oldperson clock reset` | move the clock back to the top, at the normal size |

### Extras

For the tinkerers. Icon names come from [wowhead.com/icons](https://www.wowhead.com/icons);
`reset` puts back the default.

| Command | What it does |
|---|---|
| `/oldperson stretch icon buff <name>` | Fresh as a Daisy and Spring in Your Step icon |
| `/oldperson stretch icon debuff <name>` | Stiff Joints icon |
| `/oldperson stretch icon reset` | both back to the default |
| `/oldperson alarm icon <name>` | Responsibilities icon |
| `/oldperson bedtime icon <name>` | Past Your Bedtime icon |
| `/oldperson quiet icon <name>` | Earmuffs icon |

## License

MIT, see [LICENSE](LICENSE).
