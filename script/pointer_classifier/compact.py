"""The compact input: the cascade request's `state` as the encoder reads it.

Jev is sent about 12 KB of fixed instructions with every line. A model
trained for this one job does not need them -- the instructions are baked
into its heads -- so its input is only the typed line and the records the
engine offered, each one a short segment the pointer head can point at:

    [CLS] player: give the daybook to Halkett Rowe [SEP] here: Ward Office 12 [SEP]
    way out: The Long Hallway [SEP] person: Halkett Rowe, also Rowe [SEP]
    carried: Ward Office 12 daybook [SEP] action: Offer Ward Office 12 daybook ... [SEP]

Records come in the engine's own state order (`cascade::State`: ways out,
people, things lying here, things carried, physical attempts), under the
engine's own keys, so an answer is a key the engine sent. Nothing here reads
anything but the request.
"""

GROUPS = (
    ("ways_out", "way out"),
    ("other_characters", "person"),
    ("available_items", "lying here"),
    ("player_items", "carried"),
    ("physical_actions", "action"),
)

# The intents the cascade asks about, in `request.yml`'s order. `throw` is not
# one of them: a throw is only ever read by the classifier model.
INTENTS = ("move", "talk", "examine", "take", "drop", "attack", "use", "other")

# The intents with a target question, each a head of its own.
TARGET_ACTIONS = ("move", "talk", "attack", "take", "drop", "examine", "use")

NOTHING = "nothing"

MAX_LINE_TOKENS = 64
MAX_RECORD_TOKENS = 32
MAX_TOKENS = 512


def records(state):
    """[(key, segment text)] in the engine's state order."""
    found = []
    for group, label in GROUPS:
        for key, entry in (state.get(group) or {}).items():
            text = f"{label}: {entry['name']}"
            aliases = [a for a in entry.get("aliases") or [] if a]
            if aliases:
                text += ", also " + ", ".join(aliases)
            found.append((key, text))
    return found


def encode(tokenizer, state, line=None):
    """Token ids and, per record, the span of its tokens.

    Returns (ids, keys, spans) where spans[i] is (start, end) of keys[i]'s
    tokens in ids. The line is `line` when given, else the state's own
    `player_action`.
    """
    line = state.get("player_action", "") if line is None else line
    cls, sep = tokenizer.cls_token_id, tokenizer.sep_token_id

    def piece(text, limit):
        return tokenizer.encode(text, add_special_tokens=False)[:limit]

    ids = [cls] + piece("player: " + line, MAX_LINE_TOKENS) + [sep]
    ids += piece("here: " + (state.get("location") or ""), MAX_RECORD_TOKENS) + [sep]
    keys, spans = [], []
    for key, text in records(state):
        body = piece(text, MAX_RECORD_TOKENS)
        if len(ids) + len(body) + 1 > MAX_TOKENS:
            break
        spans.append((len(ids), len(ids) + len(body)))
        keys.append(key)
        ids += body + [sep]
    return ids, keys, spans
