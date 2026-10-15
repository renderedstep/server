"""The owner's own typed lines that the classifier MODEL read, as training rows.

    python live_lines.py <copy of the development database> <corpus yml> <out.jsonl>

Reads a COPY of the database (opened read-only) and never the database
itself. Every classifier conversation stores the prompt the model was shown
-- the room's closed sets and the typed line -- and the answer it gave; that
answer is the label. Which lines count is the whole point of this file:

  * `scenes.resolved_by = 'model'`: the classifier model read the line alone.
  * a classifier answer with no scene, written before System One was first
    switched on (`SYSTEM_ONE_FIRST_LIVE`): nothing but the model can have
    read it.
  * NEVER `typed_model` or `typed_model_escalated`. A `typed_model` line was
    read by Jev, and TypeSafe's terms forbid training on Jev's outputs; an
    escalated line's answer is the model's, but it was chosen for escalation
    by Jev's own readings, so it is left out too.

A line whose typed text is also a classifier corpus line is dropped: the
corpus was partly lifted from these same conversations, and training on its
own lines would measure memory. The two yes/no readings are not labelled
here -- the model call answers neither -- so a row carries no noul label.
"""

import json
import re
import sqlite3
import sys

import yaml

SYSTEM_ONE_FIRST_LIVE = "2026-09-27"

GROUPS = {
    "Ways Out": ("ways_out", "way", "way out", ["move"]),
    "Who Is Here": ("other_characters", "person", "person present here", ["talk", "attack"]),
    "What Is Lying Here": ("available_items", "available_item", "item lying here", ["take", "examine"]),
    "What The Player Is Carrying": ("player_items", "player_item", "item the player is carrying", ["drop", "examine"]),
}

TARGET_GROUPS = {
    "move": ["ways_out"],
    "talk": ["other_characters"],
    "attack": ["other_characters"],
    "take": ["available_items"],
    "drop": ["player_items"],
    "examine": ["available_items", "player_items"],
    "use": ["physical_actions"],
}


def normalized(text):
    return re.sub(r"[^a-z0-9]+", " ", text.lower()).strip()


def sections(prompt):
    found, heading = {}, None
    for row in prompt.splitlines():
        if row.startswith("## "):
            heading = row[3:].strip()
            found[heading] = []
        elif heading and row.strip():
            found[heading].append(row.rstrip())
    return found


def state_from(prompt):
    """The cascade `state` the engine would build for this prompt's room, and
    the token each physical attempt was listed under."""
    parts = sections(prompt)
    state = {"location": " ".join(parts.get("Where The Player Is", [])).strip()}
    for heading, (group, prefix, kind, intents) in GROUPS.items():
        entries = {}
        for row in parts.get(heading, []):
            if not row.startswith("- "):
                continue
            name, aliases = row[2:].strip(), []
            paren = re.match(r"^(.*?) \((.*)\)$", name)
            if paren and group == "ways_out":
                name = paren.group(1)
            elif paren and group == "other_characters":
                name, aliases = paren.group(1), [paren.group(2)]
            entry = {"kind": kind, "name": name}
            if aliases:
                entry["aliases"] = aliases
            entry["valid_intents"] = intents
            entries[f"{prefix}_{len(entries) + 1}"] = entry
        state[group] = entries
    attempts, tokens = {}, {}
    for row in parts.get("Physical Actions (token: one attempt)", []):
        if ": " not in row:
            continue
        token, name = row.split(": ", 1)
        key = f"attempt_{len(attempts) + 1}"
        attempts[key] = {"kind": "one complete physical action attempt", "name": name.strip(),
                         "valid_intents": ["use"]}
        tokens[token.strip()] = key
    state["physical_actions"] = attempts
    state["player_action"] = "\n".join(parts.get("The Player Types", [])).strip()
    return state, tokens


def key_for(state, tokens, groups, name):
    if name in (None, "", "nothing"):
        return "nothing"
    if name in tokens and "physical_actions" in groups:
        return tokens[name]
    for group in groups:
        for key, entry in state.get(group, {}).items():
            if entry["name"] == name or name in entry.get("aliases", []):
                return key
    return None


def rows(database, corpus_lines):
    connection = sqlite3.connect(f"file:{database}?mode=ro", uri=True)
    answers = connection.execute(
        """
        SELECT m.id, m.chat_id, m.content, m.created_at, s.resolved_by, s.id
        FROM messages m JOIN chats c ON c.id = m.chat_id LEFT JOIN scenes s ON s.id = m.scene_id
        WHERE c.purpose = 'classifier' AND m.role = 'assistant' ORDER BY m.id
        """
    ).fetchall()
    kept, skipped = [], {}

    def skip(why):
        skipped[why] = skipped.get(why, 0) + 1

    for message, chat, content, created, resolved_by, scene in answers:
        if resolved_by in ("typed_model", "typed_model_escalated"):
            skip(f"read by System One ({resolved_by})")
            continue
        if scene is None and created >= SYSTEM_ONE_FIRST_LIVE:
            skip("no scene, and written after System One was live")
            continue
        if scene is not None and resolved_by != "model":
            skip(f"resolved by {resolved_by}")
            continue
        prompt = connection.execute(
            "SELECT content FROM messages WHERE chat_id = ? AND role = 'user' AND id < ? ORDER BY id DESC LIMIT 1",
            (chat, message),
        ).fetchone()
        if not prompt:
            skip("no prompt stored")
            continue
        state, tokens = state_from(prompt[0])
        typed = state["player_action"]
        if normalized(typed) in corpus_lines:
            skip("the same line is in the classifier corpus")
            continue
        try:
            answer = json.loads(content)
        except (TypeError, ValueError):
            skip("answer is not JSON")
            continue
        intent = answer.get("intent")
        if intent not in TARGET_GROUPS and intent != "other":
            skip(f"intent {intent} is not one the cascade asks")
            continue
        target = None
        if intent in TARGET_GROUPS:
            target = key_for(state, tokens, TARGET_GROUPS[intent], answer.get("target"))
            if target is None:
                skip("target is not on the intent's own list")
                continue
            if target != "nothing" and not state[TARGET_GROUPS[intent][0]] and len(TARGET_GROUPS[intent]) == 1:
                skip("target on an empty list")
                continue
        also = key_for(state, tokens, [g for g in GROUPS_ORDER], answer.get("also_named"))
        if also is None or (also != "nothing" and also == target):
            also = "nothing"
        kept.append({
            "source": f"owner message {message}",
            "state": state,
            "line": typed,
            "label": {"intent": intent, "target": [target] if target else None, "also": [also],
                      "named_more_than_one": None, "target_present": None},
        })
    return kept, skipped


GROUPS_ORDER = ["ways_out", "other_characters", "available_items", "player_items", "physical_actions"]


def main():
    database, corpus, out = sys.argv[1:4]
    with open(corpus) as source:
        corpus_lines = {normalized(line["typed"]) for line in yaml.safe_load(source)["lines"]}
    kept, skipped = rows(database, corpus_lines)
    with open(out, "w") as sink:
        for row in kept:
            sink.write(json.dumps(row) + "\n")
    print(json.dumps({"kept": len(kept), "skipped": skipped}, indent=2))


if __name__ == "__main__":
    main()
