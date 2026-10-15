"""Typed lines for a staged room, each labelled by how it was built.

A line written as "take the <a thing lying here>" is a `take` of that thing
because it was written that way: the label is the construction, so no model
-- and in particular no stored Jev answer -- is consulted. That is the whole
reason this file exists: TypeSafe's terms forbid training on Jev's outputs,
and these labels cost nothing.

A label is what the cascade's questions should answer for the line:

    intent                 one of compact.INTENTS
    target                 the acceptable keys for the intent's own target
                           question, ["nothing"], or None where no target is
                           read (`other`)
    also                   the acceptable keys for `also_named`, or ["nothing"]
    named_more_than_one    0 or 1
    target_present         0 or 1

`target` and `also` are SETS: "take the lamp and the rope" is answered right
by either record first, as the corpus scores it.

The phrasings are this file's own, written from the cascade's question texts
(the engine's `data/playthrough/classifier/request.yml`) and NOT from the
classifier corpus, which is the yardstick and must stay unseen. A thing named
here that is not in the room comes from `vocabulary.yml`, checked against the
room so it really is absent.
"""

import os
import random
import re

import yaml

from compact import NOTHING

VOCABULARY = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "lib", "eval", "classifier",
                          "pointer", "vocabulary.yml")

ATTEMPT_FORMS = (
    ("consume", re.compile(r"^Consume (?P<item>.+)$")),
    ("offer", re.compile(r"^Offer (?P<item>.+) to (?P<person>.+); they may refuse$")),
    ("burn", re.compile(r"^Burn (?P<item>.+) with (?P<tool>.+)$")),
    ("unlock", re.compile(r"^Unlock the way to (?P<place>.+) with (?P<tool>.+)$")),
    ("pick", re.compile(r"^Pick the lock to (?P<place>.+) with (?P<tool>.+)$")),
    ("pry", re.compile(r"^Pry open the way to (?P<place>.+) with (?P<tool>.+)$")),
    ("force", re.compile(r"^Force open the jammed way to (?P<place>.+)$")),
)

ARTICLES = ("the ", "a ", "an ")

# What a room is made of but never lists: looking at it reads nothing.
SCENERY = ("the window", "the wall", "the ceiling", "the floor", "the sky", "the shelves", "the corner",
           "the rafters", "the doorframe", "the rain", "the dust", "the stains on the wall", "the far wall")


def vocabulary():
    with open(VOCABULARY) as source:
        return yaml.safe_load(source)


def strip_article(name):
    lower = name.lower()
    for article in ARTICLES:
        if lower.startswith(article):
            return name[len(article):]
    return name


class Room:
    """A staged state, read into what a line can name."""

    def __init__(self, state, words):
        self.state = state
        self.words = words
        group = lambda key: list((state.get(key) or {}).items())  # noqa: E731
        self.ways = group("ways_out")
        self.people = group("other_characters")
        self.lying = group("available_items")
        self.carried = group("player_items")
        self.attempts = []
        for key, entry in group("physical_actions"):
            for kind, form in ATTEMPT_FORMS:
                found = form.match(entry["name"])
                if found:
                    self.attempts.append((key, kind, found.groupdict()))
                    break
        self.names = {entry["name"].lower() for _, entry in self.ways + self.people + self.lying + self.carried}
        for _, entry in self.people:
            self.names.update(alias.lower() for alias in entry.get("aliases") or [])

    def key_named(self, entries, name):
        return next((key for key, entry in entries if entry["name"] == name), None)


# --- how a record is referred to ------------------------------------------------


def place_head(name, words):
    lower = strip_article(name).lower()
    heads = sorted((h.lower() for h in words["place_heads"]), key=len, reverse=True)
    for head in heads:
        if re.search(rf"\b{re.escape(head)}\b", lower):
            return head
    return lower.split()[-1]


def place_refs(name, words):
    head = place_head(name, words)
    bare = strip_article(name)
    last = re.sub(r"^.*'s ", "", bare.lower()).split()[-1]
    refs = [name, name.lower(), bare, "the " + bare.lower(), "the " + head, head, "the " + last, last]
    if re.search(r"\d+$", name):
        refs.append(f"{head} {name.split()[-1]}")
    return refs


def item_head(name):
    bare = strip_article(name).lower()
    if " of " in bare:
        return bare.split(" of ", 1)[1].split()[-1]
    words = [w for w in bare.split() if not w.isdigit()]
    return words[-1] if words else bare


def item_refs(name, carried=False):
    """Every way a player shortens a thing's name: whole, by its head noun, by
    the last part of a hyphenated head, by its last two words."""
    bare = strip_article(name)
    head = item_head(name)
    words = [w for w in re.sub(r"^.*'s ", "", bare.lower()).split() if not w.isdigit()]
    refs = [name, "the " + bare, "the " + bare.lower(), bare.lower(), "the " + head, head]
    if "-" in head:
        refs += ["the " + head.split("-")[-1], "the " + head.replace("-", " "), head.replace("-", " ")]
    if len(words) >= 2:
        refs.append("the " + " ".join(words[-2:]))
    if " of " in bare.lower():
        refs.append("the " + bare.lower().split(" of ", 1)[0].split()[-1])
    if carried:
        refs += ["my " + bare.lower(), "my " + head]
    return refs


def renamed(state, rng, novel):
    """The room with some things and places given names nobody chose.

    The vocabulary is small, and a model that saw only its head nouns learns
    those nouns rather than learning to match a name in the line against a
    name in the state. So most rooms have some of their things and ways out
    renamed from `novel` -- ordinary words drawn from the encoder's own
    vocabulary -- written into every record that carries the name, attempts
    included, exactly as the engine would have written it.
    """
    if not novel or rng.random() < 0.3:
        return state
    pick = lambda: rng.choice(novel)  # noqa: E731
    changes = {}
    for group in ("available_items", "player_items"):
        for entry in (state.get(group) or {}).values():
            if rng.random() < 0.6:
                changes[entry["name"]] = rng.choice([
                    f"{pick()}", f"{pick()} {pick()}", f"{pick()}-{pick()}", f"{pick().title()} {pick()}",
                    f"{pick()} of {pick()}", f"{pick().title()}'s {pick()}", f"{pick()} {rng.randint(2, 99)}",
                ])
    for entry in (state.get("ways_out") or {}).values():
        if rng.random() < 0.6:
            changes[entry["name"]] = rng.choice([
                f"The {pick().title()}", f"The {pick().title()} {pick().title()}", f"{pick().title()} {pick()}",
                f"{pick().title()}'s {pick().title()}", f"The {pick().title()} {rng.randint(2, 40)}",
            ])
    if len({value.lower() for value in changes.values()}) < len(changes):
        return state
    new = {}
    for group, entries in state.items():
        if not isinstance(entries, dict):
            new[group] = entries
            continue
        new[group] = {}
        for key, entry in entries.items():
            entry = dict(entry)
            name = entry["name"]
            if name in changes:
                entry["name"] = changes[name]
            elif group == "physical_actions":
                for old in sorted(changes, key=len, reverse=True):
                    name = re.sub(rf"(?<![\w-]){re.escape(old)}(?![\w-])", changes[old], name)
                entry["name"] = name
            new[group][key] = entry
    return new


def person_refs(entry):
    full = entry["name"]
    parts = full.split()
    refs = [full, full.lower(), parts[0], parts[-1]]
    for alias in entry.get("aliases") or []:
        refs.append(alias)
        if alias.lower().startswith("the "):
            refs.append(alias[4:])
    return refs


def unique_refs(room, key, refs, pool):
    """The references to `key` that no other record in `pool` shares."""
    taken = set()
    for other_key, other_refs in pool:
        if other_key != key:
            taken.update(r.lower() for r in other_refs)
    seen, kept = set(), []
    for ref in refs:
        lowered = ref.lower()
        if lowered not in taken and lowered not in seen:
            seen.add(lowered)
            kept.append(ref)
    return kept


# --- the generators ---------------------------------------------------------


def label(intent, target=None, also=None, two=0, present=1):
    return {"intent": intent, "target": target, "also": also or [NOTHING], "named_more_than_one": two,
            "target_present": present}


class Lines:
    def __init__(self, room, rng):
        self.room = room
        self.rng = rng
        words = room.words
        self.words = words
        everything = room.ways + room.people + room.lying + room.carried
        self.pool = (
            [(k, place_refs(e["name"], words)) for k, e in room.ways]
            + [(k, person_refs(e)) for k, e in room.people]
            + [(k, item_refs(e["name"])) for k, e in room.lying]
            + [(k, item_refs(e["name"], carried=True)) for k, e in room.carried]
        )
        self.refs = {k: unique_refs(room, k, refs, self.pool) for k, refs in self.pool}
        self.entries = {k: e for k, e in everything}

    def ref(self, key):
        refs = self.refs.get(key) or [self.entries[key]["name"]]
        return self.rng.choice(refs)

    def pick(self, items):
        return self.rng.choice(items)

    def absent(self, kind):
        """A name of `kind` the room does not hold."""
        words = self.words
        for _ in range(30):
            if kind == "place":
                name = f"the {self.rng.choice(words['place_adjectives']).lower()} " \
                       f"{self.rng.choice(words['place_heads']).lower()}"
                if self.rng.random() < 0.3:
                    name = f"{self.rng.choice(words['place_proper'])} {self.rng.choice(words['place_heads'])}"
            elif kind == "person":
                name = self.rng.choice([
                    self.rng.choice(words["first_names"]),
                    f"{self.rng.choice(words['first_names'])} {self.rng.choice(words['surnames'])}",
                    f"the {self.rng.choice(words['roles'])}",
                ])
            else:
                name = self.rng.choice([
                    f"the {self.rng.choice(words['item_nouns'])}",
                    f"the {self.rng.choice(words['item_adjectives'])} {self.rng.choice(words['item_nouns'])}",
                    f"the {self.rng.choice(words['foods'])}",
                ])
            bare = strip_article(name).lower()
            if bare in self.room.names or any(bare in n or n.endswith(" " + bare.split()[-1]) for n in self.room.names):
                continue
            return name
        return None

    # -- move
    def move(self):
        if not self.room.ways:
            return None
        key, _ = self.pick(self.room.ways)
        where = self.ref(key)
        verb = self.pick(["go to", "walk to", "head to", "go into", "walk into", "enter", "step into",
                          "make my way to", "head over to", "go through to", "cross to", "run to", "return to",
                          "hurry to", "leave for", "set off for", "wander over to", "climb to", "go out to",
                          "slip into", "go back to", "take the way to", "follow the path to", "walk over to"])
        text = self.pick([f"{verb} {where}", f"{verb} {where}", f"I {verb} {where}", where, f"to {where}",
                          f"let's {verb} {where}", f"{verb} {where} now", f"i want to {verb} {where}",
                          f"{verb} {where} and look for a way on", f"quietly {verb} {where}"])
        return text, label("move", [key])

    def move_absent(self):
        where = self.absent("place")
        if not where:
            return None
        verb = self.pick(["go to", "walk to", "head for", "go into", "enter", "climb up to", "find",
                          "go down to", "look for a way to", "go back to"])
        target = [NOTHING] if self.room.ways else None
        return f"{verb} {where}", label("move", target, present=0)

    def leave(self):
        if len(self.room.ways) != 1:
            return None
        key = self.room.ways[0][0]
        text = self.pick(["leave", "leave this place", "go out", "get out of here", "walk out", "exit",
                          "go through the only door", "head out"])
        return text, label("move", [key])

    # -- talk
    def talk(self):
        if not self.room.people:
            return None
        key, entry = self.pick(self.room.people)
        who = self.ref(key)
        topic = self.topic()
        text = self.pick([
            f"talk to {who}", f"speak with {who}", f"ask {who} about {topic}", f"say hello to {who}",
            f"greet {who}", f"{who}, what happened here?", f'"Good evening," I say to {who}',
            f"tell {who} that I mean no harm", f"ask {who} where {topic} is", f"chat with {who}",
            f"ask {who} for help", f"{who}, do you know anything about {topic}?", f"call out to {who}",
            f"whisper to {who}", f"ask {who} what they are doing here", f"tell {who} my name",
            f"thank {who}", f"apologise to {who}", f"ask {who} if they have seen {topic}",
            f"hey {who}", f"shout at {who} to stop", f"warn {who} about {topic}", f"say to {who}: who are you?",
            f"threaten {who}", f"tell {who} I will hurt them if they lie", f"ask {who} to give me {topic}",
            f"insult {who}", f"beg {who} for a coin", f"question {who} about the door"])
        return text, label("talk", [key])

    def talk_absent(self):
        who = self.absent("person")
        if not who:
            return None
        text = self.pick([f"talk to {who}", f"ask {who} about the noise", f"say hello to {who}",
                          f"{who}, are you there?", f"call for {who}", f"tell {who} to come here"])
        target = [NOTHING] if self.room.people else None
        return text, label("talk", target, present=0)

    def talk_unnamed(self):
        if len(self.room.people) != 1:
            return None
        key = self.room.people[0][0]
        pronoun = self.pick(["him", "her", "them"])
        text = self.pick([f"talk to {pronoun}", f"ask {pronoun} what happened", f"say hello to {pronoun}",
                          "hello there", "who are you?", "excuse me, can you help?", f"greet {pronoun}",
                          f"tell {pronoun} to leave", f"ask {pronoun} their name"])
        return text, label("talk", [key])

    def topic(self):
        options = [entry["name"].lower() for _, entry in self.room.lying + self.room.carried + self.room.ways]
        options += ["the weather", "the town", "the old days", "the noise last night", "the way out"]
        return self.pick(options)

    # -- attack
    def attack(self):
        if not self.room.people:
            return None
        key, _ = self.pick(self.room.people)
        who = self.ref(key)
        weapon = self.pick(["", "", " with my fist", " with the stick", " hard", " in the face", " from behind"])
        verb = self.pick(["hit", "punch", "kick", "attack", "strike", "stab", "shove", "tackle", "slap",
                          "grab and throttle", "headbutt", "knock down", "swing at", "lunge at", "fight", "elbow"])
        return self.pick([f"{verb} {who}{weapon}", f"I {verb} {who}{weapon}"]), label("attack", [key])

    def attack_absent(self):
        who = self.absent("person")
        if not who:
            return None
        target = [NOTHING] if self.room.people else None
        return f"{self.pick(['hit', 'attack', 'punch', 'stab'])} {who}", label("attack", target, present=0)

    # -- take
    def take(self):
        if not self.room.lying:
            return None
        key, _ = self.pick(self.room.lying)
        thing = self.ref(key)
        verb = self.pick(["take", "pick up", "grab", "get", "collect", "snatch", "pocket", "lift", "take hold of",
                          "scoop up", "pick", "swipe", "help myself to", "fetch"])
        if verb == "pick":
            text = f"pick {thing} up"
        else:
            text = self.pick([f"{verb} {thing}", f"I {verb} {thing}", f"try to {verb} {thing}",
                              f"{verb} {thing} and put it in my bag", f"carefully {verb} {thing}"])
        return text, label("take", [key])

    def take_absent(self):
        thing = self.absent("item")
        if not thing:
            return None
        target = [NOTHING] if self.room.lying else None
        return f"{self.pick(['take', 'pick up', 'grab', 'get'])} {thing}", label("take", target, present=0)

    def take_pronoun(self):
        if len(self.room.lying) != 1:
            return None
        return self.pick(["take it", "pick it up", "grab it", "take that"]), label("take", [self.room.lying[0][0]])

    # -- drop
    def drop(self):
        if not self.room.carried:
            return None
        key, _ = self.pick(self.room.carried)
        thing = self.ref(key)
        verb = self.pick(["drop", "put down", "set down", "leave", "discard", "get rid of", "throw away",
                          "toss aside", "abandon", "lay down", "dump", "let go of"])
        text = self.pick([f"{verb} {thing}", f"I {verb} {thing}", f"{verb} {thing} here",
                          f"{verb} {thing} on the floor", f"put {thing} down"])
        return text, label("drop", [key])

    def drop_absent(self):
        thing = self.absent("item")
        if not thing:
            return None
        target = [NOTHING] if self.room.carried else None
        return f"{self.pick(['drop', 'put down', 'set down'])} {thing}", label("drop", target, present=0)

    def drop_pronoun(self):
        if len(self.room.carried) != 1:
            return None
        return self.pick(["drop it", "put it down", "set it down"]), label("drop", [self.room.carried[0][0]])

    # -- examine
    def examine(self):
        things = self.room.lying + self.room.carried
        if not things:
            return None
        key, _ = self.pick(things)
        thing = self.ref(key)
        verb = self.pick(["look at", "examine", "inspect", "read", "study", "check", "look closely at",
                          "peer at", "search", "turn over", "look over", "squint at", "investigate", "feel",
                          "sniff", "look inside", "flip through"])
        text = self.pick([f"{verb} {thing}", f"I {verb} {thing}", f"{verb} {thing} carefully",
                          f"what is {thing}?", f"{verb} {thing} for anything odd"])
        return text, label("examine", [key])

    def examine_absent(self):
        thing = self.absent("item") if self.rng.random() < 0.6 else self.pick(SCENERY)
        if not thing:
            return None
        target = [NOTHING] if self.room.lying or self.room.carried else None
        verb = self.pick(["look at", "examine", "inspect", "read", "study", "search", "look out of",
                          "look under", "look behind"])
        return f"{verb} {thing}", label("examine", target, present=0)

    def look_around(self):
        target = [NOTHING] if self.room.lying or self.room.carried else None
        text = self.pick(["look around", "look around the room", "look", "survey the room", "what is here?",
                          "describe the room", "take in my surroundings", "glance around",
                          "search the room", "check my surroundings", "where am I?", "l", "look about"])
        return text, label("examine", target)

    # -- use
    def use(self):
        if not self.room.attempts:
            return None
        key, kind, parts = self.pick(self.room.attempts)
        item = lambda name: self.pick(["the " + strip_article(name).lower(), strip_article(name),  # noqa: E731
                                       "the " + item_head(name), "my " + item_head(name)])
        place = lambda name: self.pick(["the door to " + name, "the way to " + name,  # noqa: E731
                                        "the " + place_head(name, self.words) + " door", "the door"])
        if kind == "consume":
            verb = self.pick(["eat", "drink", "consume", "swallow", "gulp down", "nibble", "finish", "use",
                              "apply", "take a bite of", "quaff", "have"])
            text = f"{verb} {item(parts['item'])}"
        elif kind == "offer":
            who = self.pick(self.refs_for_name(parts["person"]))
            thing = item(parts["item"])
            text = self.pick([f"give {thing} to {who}", f"offer {thing} to {who}", f"hand {thing} to {who}",
                              f"give {who} {thing}", f"hand {who} {thing}", f"show {who} {thing} and hand it over",
                              f"pass {thing} to {who}", f"let {who} have {thing}"])
        elif kind == "burn":
            text = self.pick([f"burn {item(parts['item'])} with {item(parts['tool'])}",
                              f"set fire to {item(parts['item'])}", f"light {item(parts['item'])} on fire",
                              f"use {item(parts['tool'])} to burn {item(parts['item'])}"])
        elif kind in ("unlock", "pick", "pry"):
            verb = {"unlock": "unlock", "pick": "pick the lock on", "pry": "pry open"}[kind]
            text = self.pick([f"{verb} {place(parts['place'])} with {item(parts['tool'])}",
                              f"use {item(parts['tool'])} on {place(parts['place'])}",
                              f"open {place(parts['place'])} with {item(parts['tool'])}"])
        else:
            text = self.pick([f"force {place(parts['place'])}", f"force open {place(parts['place'])}",
                              f"shoulder {place(parts['place'])} open", f"kick open {place(parts['place'])}",
                              f"break down {place(parts['place'])}", f"shove {place(parts['place'])} open"])
        return text, label("use", [key])

    def refs_for_name(self, fullname):
        key = self.room.key_named(self.room.people, fullname)
        refs = list(self.refs.get(key) or [fullname])
        if len(self.room.people) == 1:
            refs += ["him", "her", "them"]
        return refs

    def offer_absent(self):
        if not self.room.people:
            return None
        thing = self.absent("item")
        if not thing:
            return None
        who = self.ref(self.pick(self.room.people)[0])
        target = [NOTHING] if self.room.attempts else None
        return self.pick([f"give {thing} to {who}", f"hand {who} {thing}", f"offer {who} {thing}"]), \
            label("use", target, present=0)

    def take_from(self):
        """Asking for a thing somebody else holds: nothing lying here is it."""
        if not self.room.people:
            return None
        thing = self.absent("item")
        if not thing:
            return None
        who = self.ref(self.pick(self.room.people)[0])
        target = [NOTHING] if self.room.lying else None
        return self.pick([f"take {thing} from {who}", f"snatch {thing} out of {who}'s hands",
                          f"grab {thing} off {who}"]), label("take", target, present=0)

    def examine_person(self):
        """Looking at a person: they are listed, but not as a thing to examine."""
        if not self.room.people:
            return None
        who = self.ref(self.pick(self.room.people)[0])
        pronoun = self.pick(["him", "her", "them"])
        text = self.pick([f"look at {who}", f"study {who}'s face", f"look {pronoun} over" if len(self.room.people) == 1
                          else f"look {who} over", f"watch {who} closely", f"examine {who}'s hands",
                          f"look {who} up and down"])
        target = [NOTHING] if self.room.lying or self.room.carried else None
        return text, label("examine", target)

    def other_about(self):
        """A line that names a record and asks for no act on it."""
        named = self.room.people + self.room.lying + self.room.carried + self.room.ways
        if not named:
            return None
        key, _ = self.pick(named)
        what = self.ref(key)
        text = self.pick([f"wait for {what}", f"think about {what}", f"wonder about {what}", f"remember {what}",
                          f"consider {what} for a while", f"hesitate, thinking of {what}",
                          f"wait for {what} to say something", f"keep thinking about {what}",
                          f"daydream about {what}", f"worry about {what}"])
        return text, label("other")

    # -- other
    def other(self):
        text = self.pick([
            "wait", "wait a moment", "sit down", "rest", "sleep", "think", "think about what to do next",
            "listen", "listen carefully", "hum a tune", "sing", "pray", "sigh", "laugh", "cry", "hide",
            "stand still", "breathe deeply", "count to ten", "do nothing", "keep waiting", "close my eyes",
            "stretch", "yawn", "whistle", "dance", "jump", "kneel", "check the time", "remember the old days",
            "wonder where everyone went", "help", "what can I do?", "inventory", "check my pockets",
            "wait for something to happen", "pace up and down", "rest for an hour", "clap my hands",
            "nod", "shrug", "smile", "take a deep breath", "sit and think about the journey",
            "pretend to be asleep", "wait until nightfall", "z", "meditate", "scream", "write in my head",
        ])
        return text, label("other")

    # -- two names
    def two_one_set(self):
        choices = []
        if len(self.room.lying) >= 2:
            choices.append(("take", self.room.lying, ["take", "pick up", "grab"]))
        if len(self.room.carried) >= 2:
            choices.append(("drop", self.room.carried, ["drop", "put down", "leave"]))
        if len(self.room.lying + self.room.carried) >= 2:
            choices.append(("examine", self.room.lying + self.room.carried, ["look at", "examine", "read"]))
        if len(self.room.people) >= 2:
            choices.append(("talk", self.room.people, ["talk to", "greet", "speak with"]))
            choices.append(("attack", self.room.people, ["hit", "attack", "punch"]))
        if len(self.room.ways) >= 2:
            choices.append(("move", self.room.ways, ["go to", "walk to"]))
        if not choices:
            return None
        intent, entries, verbs = self.pick(choices)
        (a, _), (b, _) = self.rng.sample(entries, 2)
        verb = self.pick(verbs)
        joiner = self.pick([" and ", " and then ", ", then ", " and also ", " and "])
        if intent == "move":
            text = f"{verb} {self.ref(a)}{joiner}{verb} {self.ref(b)}" if self.rng.random() < 0.5 \
                else f"{verb} {self.ref(a)} and then on to {self.ref(b)}"
        elif intent == "talk" and self.rng.random() < 0.5:
            text = self.pick([f"tell {self.ref(a)} that {self.ref(b)} is lying",
                              f"ask {self.ref(a)} about {self.ref(b)}",
                              f"introduce {self.ref(a)} to {self.ref(b)}"])
        else:
            second = self.pick([self.ref(b), f"{verb} {self.ref(b)}"])
            text = f"{verb} {self.ref(a)}{joiner}{second}"
        # THE FIRST NAMED IS THE TARGET AND THE SECOND IS `also_named`. Both
        # sets accepting either record let the model name the same one twice,
        # which the engine collapses to one name and the line to one act.
        return text, label(intent, [a], [b], two=1)

    def collective(self):
        choices = []
        if len(self.room.lying) >= 2:
            choices.append(("take", self.room.lying, ["take everything", "pick up everything", "grab it all",
                                                      "take all of it", "take the lot", "take both",
                                                      "pick them all up"]))
        if len(self.room.carried) >= 2:
            choices.append(("drop", self.room.carried, ["drop everything", "put it all down", "drop the lot",
                                                        "drop all my things", "empty my hands"]))
        if len(self.room.people) >= 2:
            choices.append(("talk", self.room.people, ["talk to them both", "greet everyone", "ask them all",
                                                       "speak to both of them"]))
            choices.append(("attack", self.room.people, ["attack them both", "fight them all"]))
        if not choices:
            return None
        intent, entries, texts = self.pick(choices)
        keys = [k for k, _ in entries]
        # A collective word names them in no order, so the state's order
        # decides: the first as the target, the second as the other name.
        return self.pick(texts), label(intent, keys[:1], keys[1:2], two=1)

    def two_sets(self):
        """Two acts of different kinds: the first is the intent, nothing second."""
        firsts = [g for g in (self.take, self.drop, self.move, self.talk, self.examine) if g() is not None]
        if not firsts:
            return None
        first = self.pick(firsts)()
        if first is None:
            return None
        text, first_label = first
        seconds = [g for g in (self.take, self.drop, self.move, self.talk, self.examine, self.other)]
        for _ in range(5):
            second = self.pick(seconds)()
            if second and second[1]["intent"] != first_label["intent"]:
                joined = text + self.pick([" and ", " and then ", ", then ", " before I "]) + second[0]
                return joined, first_label
        return None

    GENERATORS = (
        ("move", 10), ("move_absent", 3), ("leave", 1), ("talk", 10), ("talk_absent", 2), ("talk_unnamed", 2),
        ("attack", 4), ("attack_absent", 1), ("take", 7), ("take_absent", 2), ("take_pronoun", 1),
        ("drop", 5), ("drop_absent", 1), ("drop_pronoun", 1), ("examine", 6), ("examine_absent", 3),
        ("look_around", 2), ("use", 5), ("other", 6), ("two_one_set", 5), ("collective", 1), ("two_sets", 4),
        ("other_about", 3), ("examine_person", 2), ("take_from", 1), ("offer_absent", 1),
    )

    def sample(self, count):
        names = [n for n, _ in self.GENERATORS]
        weights = [w for _, w in self.GENERATORS]
        made, tries = [], 0
        while len(made) < count and tries < count * 6:
            tries += 1
            built = getattr(self, self.rng.choices(names, weights)[0])()
            if built is None:
                continue
            text, line_label = built
            made.append((roughen(text, self.rng), line_label))
        return made


def roughen(text, rng):
    """The surface a player gives a line: case, punctuation, the odd slip."""
    roll = rng.random()
    if roll < 0.35:
        text = text.lower()
    elif roll < 0.45:
        text = text[:1].upper() + text[1:]
    if rng.random() < 0.15 and not text.endswith(("?", ".", "!")):
        text += rng.choice([".", "!", "..."])
    if rng.random() < 0.06 and len(text) > 6:
        i = rng.randrange(1, len(text) - 1)
        text = text[:i] + text[i + 1:] if rng.random() < 0.5 else text[:i] + text[i + 1] + text[i] + text[i + 2:]
    if rng.random() < 0.05:
        text = rng.choice(["please ", "now ", "ok ", "then "]) + text
    return text


def lines_for(state, words, rng, count):
    """(the state the lines were written in, [(line, label)]): the state is the
    room as staged, or the same room with some names replaced (`renamed`)."""
    state = renamed(state, rng, words.get("novel"))
    return state, Lines(Room(state, words), rng).sample(count)


def novel_words(tokenizer, excluded):
    """Ordinary lower-case words from the encoder's own vocabulary, less any
    word the corpus's seeded worlds use, for `renamed`."""
    found = set()
    for token in tokenizer.get_vocab():
        word = token[1:] if token.startswith("Ġ") else None
        if word and re.fullmatch(r"[a-z]{4,10}", word) and word not in excluded:
            found.add(word)
    return sorted(found)


def seeded_words():
    """Every word in the names of the corpus's three seeded worlds."""
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "db", "seeds", "worlds")
    words = set()
    for file in os.listdir(root):
        if not file.endswith(".yml"):
            continue
        with open(os.path.join(root, file)) as source:
            document = yaml.safe_load(source)
        names = []
        for location in document.get("locations") or []:
            names.append(location.get("name") or "")
            names += [item.get("name") or "" for item in location.get("items") or []]
        for person in document.get("characters") or []:
            names += [person.get("fullname") or "", person.get("nickname") or ""]
            names += [item.get("name") or "" for item in person.get("items") or []]
        for name in names:
            words.update(re.findall(r"[a-z]+", name.lower()))
    return words


if __name__ == "__main__":
    import json
    import sys

    words = vocabulary()
    rng = random.Random(1)
    with open(sys.argv[1]) as source:
        for row in list(source)[: int(sys.argv[2]) if len(sys.argv) > 2 else 2]:
            room = json.loads(row)
            state, lines = lines_for(room["state"], words, rng, 25)
            print(json.dumps({key: [e["name"] for e in entries.values()] for key, entries in state.items()
                              if isinstance(entries, dict)}))
            for text, line_label in lines:
                print(json.dumps({"line": text, **line_label}))
