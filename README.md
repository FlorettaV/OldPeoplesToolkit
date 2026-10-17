# Old People's Toolkit

Tools for old people with responsibilities and sore bones: a "where was I?"
message at start, a notebook for things you'll forget, automated quiet hours,
a stretch reminder, a clock with an alarm, and bedtime. With pretend buffs and
debuffs.

**Real life, the WoW way.** Your reminders show up as buffs and debuffs, right
next to your real ones. Sat too long? You get **Stiff Joints** (*"Your old bones
take 50 Nature damage every minute"*). Up too late? **Past Your Bedtime**. Hover
over one for its tooltip, right-click it to act on it.

No gameplay changes. Just the grown-up stuff around playing.

Made for WoW: Forever.

## The pretend buffs and debuffs

Addons can't give your character real buffs, so these are icons that look like
them, lined up at the end of your buff and debuff rows. Each one can be turned
off in the options, and you can pick your own icons (names from [wowhead.com/icons](https://www.wowhead.com/icons)).

## The tools

### 🧭 Where was I?
- Log in after a while away (8 hours by default) and a window tells you when
  and where you last played, and which quests you were busy with.
- Had to stop in a hurry? It also shows what your bags were filling up with in
  your last half hour, like the boar meat you were farming or the bandages you
  were making. Closed up shop properly? Then there's nothing to remind you of.
- Fully automatic: it follows the quests you accepted or made progress on, and
  what you looted, gathered or crafted. Nothing to write down. Per character.
- Set it to 0 hours to see it every time you log in. Hopping over to your bank
  alt? Turn on "Skip an empty window" and there's no window when there's
  nothing to remind you of.

### 📜 Scrolls of Remembering
- A notebook for everything you'll definitely forget: *what is this meat for?*,
  *someone said Mankrik, go look*, *something weird here, come back some time*.
- You learn it like a spell. It's tucked in your spellbook: drag it to your
  action bar to cast it, or type `/oldperson notes`. There's a keybind too.
- Each note remembers where you were standing. Shift-click a note and a pin on
  your map takes you back.
- Shift-click an item to add it, or target someone (a creature, a vendor,
  another player) to add their name. Hover a creature's name later for its
  tooltip and a sketch of its face.
- Done with a note? Click it to cross it out, right-click it to tear it off.
  No lists to manage.
- Your last scribble waits under the Where was I? window. The scroll is for
  your whole account: every character writes in the same one.

### 🎧 Quiet hours
- At night (23:00 to 07:00 by default) the game's volume goes down, so you
  don't wake the house, and back up in the morning.
- Change the volume yourself and it leaves your choice alone.
- You wear **Earmuffs** with your buffs, in Horde or Alliance colors. Headphones
  on tonight? Right-click the Earmuffs to skip quiet hours for one night.

### 🧘 Old People's Stretch
- After an hour of playing (or whatever you pick, from 15 minutes to 3 hours), a pop-up asks you to stand up and get those old bones moving.
- "Remind me in 5 min", or "I stood up and stretched" (greyed out for a few
  seconds, so you actually stretch first).
- Never during a fight. Logging out for 10 minutes or more counts as a break.
- With your buffs you start out **Fresh as a Daisy**, earn your **Second Wind**
  by stretching, and get the debuff **Stiff Joints** when it's time to stretch
  again. Stretched? Right-click it.

### 🕰️ Clock and alarm
- A bigger clock with your real (local) time. Drag it anywhere, scroll to resize.
  It replaces Blizzard's small minimap clock while it's showing.
- Click the clock to fold out the alarm. Type `15`, `1h30`, `22:30` or `10pm`
  for "I've got 15 minutes" or "I can play until 22:30".
- A heads-up 5 minutes before, and at the end: *"Time's up! I must go, my people need me!"*
- While it runs, **Responsibilities** sits with your debuffs and counts down.
  Right-click it to clear the alarm.

### 😴 Bedtime
- On work nights (Sunday to Thursday, or every night if you like): a heads-up
  15 minutes before your bedtime, and *"It's past your bedtime!"* when it's time.
- **Past Your Bedtime** sits with your debuffs until morning. Right-click it to
  hide it for tonight.

## Options

Esc > Options > AddOns > Old People's Toolkit, or click the pocket watch on the
minimap, or type `/oldperson`. Each tool has its own page under Old People's
Toolkit in the list on the left.

## Commands

`/oldperson` (or `/opt`) opens the options. `/oldperson help` lists the commands.
Settings live in the options; commands are for doing things.

| Command | What it does |
|---|---|
| `/oldperson whereami` | where you are, your quests, and what your bags are filling up with |
| `/oldperson whereami test` | the welcome-back window, as if you'd been away 3 days |
| `/oldperson notes` | open your Scrolls of Remembering |
| `/oldperson notes <anything>` | write it down without opening the scroll |
| `/oldperson stretch test` | show the stretch pop-up now |
| `/oldperson stretch done` | I stood up and stretched: start the timer over |
| `/oldperson alarm 15` | alarm in 15 minutes (or `1h30`) |
| `/oldperson alarm 22:30` | alarm at 22:30 (or `10pm`) |
| `/oldperson alarm off` | clear the alarm |
| `/oldperson clock reset` | move the clock back to the top, at the normal size |
| `/oldperson bedtime 23:30` | set your bedtime |

### Extras

For the tinkerers. Icon names come from [wowhead.com/icons](https://www.wowhead.com/icons);
`reset` puts back the default.

| Command | What it does |
|---|---|
| `/oldperson quiet icon <name>` | Earmuffs icon |
| `/oldperson stretch icon buff <name>` | Fresh as a Daisy and Second Wind icon |
| `/oldperson stretch icon debuff <name>` | Stiff Joints icon |
| `/oldperson stretch icon reset` | both back to the default |
| `/oldperson alarm icon <name>` | Responsibilities icon |
| `/oldperson bedtime icon <name>` | Past Your Bedtime icon |

## License

MIT, see [LICENSE](LICENSE).
