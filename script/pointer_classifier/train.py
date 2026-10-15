"""Trains the pointer classifier on staged rooms and templated lines.

    python train.py --rooms <rooms.jsonl> --out <model dir> [--live <live.jsonl>] [--epochs 3]

`rooms.jsonl` is `rake eval:pointer_rooms`'s output: the engine's own cascade
`state` for every generated room. Each epoch writes fresh lines into those
rooms (`templates.py`, labelled by construction), so no two epochs see the same
sentences. `--live` adds the owner's model-read lines (`live_lines.py`),
repeated `--live-repeat` times because there are few of them. A slice of the
rooms is held back and scored after every epoch; the classifier corpus is
never read here -- it is the yardstick, and `rake eval:classifier` is where it
is used.

CPU only, deterministic for a given seed and thread count.
"""

import argparse
import json
import math
import os
import random
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import torch  # noqa: E402
import torch.nn.functional as F  # noqa: E402

from compact import INTENTS, NOTHING, TARGET_ACTIONS  # noqa: E402
from model import NOULS, PointerClassifier, batch, encoder, option_logits, save  # noqa: E402
from templates import lines_for, vocabulary  # noqa: E402

GROUP_ORDER = ("ways_out", "other_characters", "available_items", "player_items", "physical_actions")


def options_for(state):
    """Each choice question's option keys, as the engine's request offers them."""
    keys = [(key, entry) for group in GROUP_ORDER for key, entry in (state.get(group) or {}).items()]
    found = {}
    for action in TARGET_ACTIONS:
        offered = [key for key, entry in keys if action in entry.get("valid_intents", [])]
        if offered:
            found[f"target_{action}"] = offered + [NOTHING]
    if keys:
        found["also_named"] = [key for key, _ in keys] + [NOTHING]
    return found


def losses(out, examples, keys):
    intent_targets = torch.tensor([INTENTS.index(e["label"]["intent"]) for e in examples])
    total = {"intent": F.cross_entropy(out["intent"], intent_targets)}
    pointer, also, noul = [], [], []
    for b, example in enumerate(examples):
        lab, options = example["label"], example["options"]
        question = f"target_{lab['intent']}"
        if lab["target"] is not None and question in options:
            logits = option_logits(out, b, keys[b], options[question], question)
            pointer.append(-accepted(logits, options[question], lab["target"]))
        if "also_named" in options:
            logits = option_logits(out, b, keys[b], options["also_named"], "also_named")
            also.append(-accepted(logits, options["also_named"], lab["also"]))
        for n, name in enumerate(NOULS):
            if lab.get(name) is not None:
                noul.append(F.binary_cross_entropy_with_logits(out["nouls"][b, n], torch.tensor(float(lab[name]))))
    for name, parts in (("target", pointer), ("also", also), ("noul", noul)):
        total[name] = torch.stack([p for p in parts if torch.isfinite(p)]).mean() if parts else torch.tensor(0.0)
    return total


def accepted(logits, options, acceptable):
    """log p(any acceptable option), over the question's own options."""
    logp = F.log_softmax(logits, dim=0)
    picked = [logp[i] for i, option in enumerate(options) if option in acceptable]
    return torch.logsumexp(torch.stack(picked), dim=0) if picked else torch.tensor(float("-inf"))


def examples_for(rooms, words, seed, per_room):
    rng = random.Random(seed)
    made = []
    for room in rooms:
        state = room["state"]
        options = options_for(state)
        for line, lab in lines_for(state, words, rng, per_room):
            made.append({"state": state, "line": line, "label": lab, "options": options})
    return made


def live_examples(path, repeat):
    made = []
    with open(path) as source:
        for row in source:
            row = json.loads(row)
            made.append({"state": row["state"], "line": row["line"], "label": row["label"],
                         "options": options_for(row["state"])})
    return made * repeat


def score(model, tokenizer, examples, size=64):
    model.eval()
    right = {"intent": 0, "target": 0, "also": 0, "nmto": 0, "present": 0}
    counted = {key: 0 for key in right}
    with torch.inference_mode():
        for start in range(0, len(examples), size):
            chunk = examples[start: start + size]
            ids, mask, pool, keys = batch(tokenizer, [(e["state"], e["line"]) for e in chunk])
            out = model(ids, mask, pool)
            for b, example in enumerate(chunk):
                lab, options = example["label"], example["options"]
                guess = INTENTS[int(out["intent"][b].argmax())]
                counted["intent"] += 1
                right["intent"] += guess == lab["intent"]
                question = f"target_{lab['intent']}"
                if lab["target"] is not None and question in options:
                    logits = option_logits(out, b, keys[b], options[question], question)
                    counted["target"] += 1
                    right["target"] += options[question][int(logits.argmax())] in lab["target"]
                if "also_named" in options:
                    logits = option_logits(out, b, keys[b], options["also_named"], "also_named")
                    counted["also"] += 1
                    right["also"] += options["also_named"][int(logits.argmax())] in lab["also"]
                for n, (name, short) in enumerate(zip(NOULS, ("nmto", "present"))):
                    if lab.get(name) is not None:
                        counted[short] += 1
                        right[short] += (out["nouls"][b, n] > 0).item() == bool(lab[name])
    model.train()
    return {key: round(right[key] / counted[key], 4) if counted[key] else None for key in right}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--rooms", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--live")
    parser.add_argument("--live-repeat", type=int, default=6)
    parser.add_argument("--encoder", default="jhu-clsp/ettin-encoder-17m")
    parser.add_argument("--epochs", type=int, default=3)
    parser.add_argument("--per-room", type=int, default=32)
    parser.add_argument("--batch", type=int, default=32)
    parser.add_argument("--lr", type=float, default=1e-4)
    parser.add_argument("--head-lr", type=float, default=1e-3)
    parser.add_argument("--threads", type=int, default=6)
    parser.add_argument("--seed", type=int, default=20261015)
    parser.add_argument("--held-out", type=float, default=0.04)
    arguments = parser.parse_args()

    torch.manual_seed(arguments.seed)
    torch.set_num_threads(arguments.threads)
    words = vocabulary()
    with open(arguments.rooms) as source:
        rooms = [json.loads(row) for row in source]
    random.Random(arguments.seed).shuffle(rooms)
    cut = max(1, int(len(rooms) * arguments.held_out))
    held, train_rooms = rooms[:cut], rooms[cut:]
    held_examples = examples_for(held, words, arguments.seed - 1, arguments.per_room)
    live = live_examples(arguments.live, arguments.live_repeat) if arguments.live else []

    base, tokenizer = encoder(arguments.encoder)
    model = PointerClassifier(base)
    heads = [p for name, p in model.named_parameters() if not name.startswith("encoder.")]
    optimizer = torch.optim.AdamW([
        {"params": model.encoder.parameters(), "lr": arguments.lr},
        {"params": heads, "lr": arguments.head_lr},
    ], weight_decay=0.01)
    per_epoch = math.ceil((len(train_rooms) * arguments.per_room + len(live)) / arguments.batch)
    steps = per_epoch * arguments.epochs
    warmup = max(1, steps // 20)
    schedule = torch.optim.lr_scheduler.LambdaLR(
        optimizer, lambda step: min(1.0, (step + 1) / warmup) * max(0.0, (steps - step) / max(1, steps - warmup)))

    log = {"arguments": vars(arguments), "rooms": len(rooms), "held_out_rooms": len(held),
           "live_rows": len(live) // max(1, arguments.live_repeat), "epochs": []}
    print(json.dumps({"train_rooms": len(train_rooms), "held_out_rooms": len(held), "steps": steps}), flush=True)
    model.train()
    step = 0
    started = time.time()
    for epoch in range(arguments.epochs):
        examples = examples_for(train_rooms, words, arguments.seed + epoch, arguments.per_room) + live
        random.Random(arguments.seed + 100 + epoch).shuffle(examples)
        running = {}
        for start in range(0, len(examples), arguments.batch):
            chunk = examples[start: start + arguments.batch]
            ids, mask, pool, keys = batch(tokenizer, [(e["state"], e["line"]) for e in chunk])
            out = model(ids, mask, pool)
            parts = losses(out, chunk, keys)
            loss = parts["intent"] + parts["target"] + 0.5 * parts["also"] + 0.5 * parts["noul"]
            optimizer.zero_grad()
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()
            schedule.step()
            step += 1
            for name, value in parts.items():
                running[name] = running.get(name, 0.0) * 0.98 + float(value) * 0.02
            if step % 100 == 0:
                print(json.dumps({"epoch": epoch, "step": step, "of": steps, "minutes": round((time.time() - started) / 60, 1),
                                  **{k: round(v, 4) for k, v in running.items()}}), flush=True)
        scored = score(model, tokenizer, held_examples)
        log["epochs"].append({"epoch": epoch, "held_out": scored, "minutes": round((time.time() - started) / 60, 1)})
        print(json.dumps(log["epochs"][-1]), flush=True)
        save(model, tokenizer, arguments.out, log)
    print(json.dumps({"saved": arguments.out}), flush=True)


if __name__ == "__main__":
    main()
