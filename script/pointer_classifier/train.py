"""Trains the pointer classifier on staged rooms and templated lines.

    python train.py --rooms <rooms.jsonl> --out <model dir> [--live <live.jsonl>] [--paid <labels.jsonl>] [--epochs 3]

`rooms.jsonl` is `rake eval:pointer_rooms`'s output: the engine's own cascade
`state` for every generated room. Each epoch writes fresh lines into those
rooms (`templates.py`, labelled by construction), so no two epochs see the same
sentences. `--live` adds the owner's model-read lines (`live_lines.py`),
repeated `--live-repeat` times because there are few of them. `--paid` adds the
written-and-labelled lines (`rake eval:pointer_labels`), repeated
`--paid-repeat` times, less a held-out slice of their rooms; give it once per
purchase, and each file is split by its own rooms. A slice of the
rooms is held back and scored after every epoch; the classifier corpus is
never read here -- it is the yardstick, and `rake eval:classifier` is where it
is used.

CPU only, deterministic for a given seed and thread count. A step's batch is
run in micro-batches (`--micro`) to keep memory small, and `<out>/checkpoint.pt`
is written every `--checkpoint-every` steps: run the same command again and
it resumes from the last one, so a killed run loses only those steps.
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
from templates import lines_for, novel_words, seeded_words, vocabulary  # noqa: E402

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
        options = options_for(room["state"])
        state, lines = lines_for(room["state"], words, rng, per_room)
        for line, lab in lines:
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


def paid_examples(path, held_out, seed, held_rooms):
    """The paid lines (`rake eval:pointer_labels`), split BY ROOM: a held-out
    room's lines are scored after every epoch and never trained on, so that
    figure is agreement with the labeller on rooms the model has not read. A
    room the templates hold out (`held_rooms`) is held out here too."""
    rows = []
    with open(path) as source:
        for row in source:
            row = json.loads(row)
            if "label" in row:
                rows.append(row)
    rooms = sorted({row["room"] for row in rows})
    random.Random(seed).shuffle(rooms)
    held = set(rooms[: int(len(rooms) * held_out)]) | (set(rooms) & held_rooms)
    split = {True: [], False: []}
    for row in rows:
        split[row["room"] in held].append({"state": row["state"], "line": row["line"], "label": row["label"],
                                           "options": options_for(row["state"])})
    return split[False], split[True]


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
    parser.add_argument("--paid", action="append", default=[],
                        help="labels.jsonl from `rake eval:pointer_labels`; once per purchase")
    parser.add_argument("--paid-repeat", type=int, default=4)
    parser.add_argument("--paid-held-out", type=float, default=0.1, help="share of the paid ROOMS held out")
    parser.add_argument("--encoder", default="jhu-clsp/ettin-encoder-17m")
    parser.add_argument("--epochs", type=int, default=3)
    parser.add_argument("--per-room", type=int, default=32)
    parser.add_argument("--batch", type=int, default=32)
    parser.add_argument("--micro", type=int, default=8, help="examples per forward pass; --batch per optimizer step")
    parser.add_argument("--checkpoint-every", type=int, default=50, help="optimizer steps between checkpoints")
    parser.add_argument("--lr", type=float, default=1e-4)
    parser.add_argument("--head-lr", type=float, default=1e-3)
    parser.add_argument("--threads", type=int, default=6)
    parser.add_argument("--seed", type=int, default=20261015)
    parser.add_argument("--held-out", type=float, default=0.04)
    arguments = parser.parse_args()

    torch.manual_seed(arguments.seed)
    torch.set_num_threads(arguments.threads)
    words = vocabulary()
    base, tokenizer = encoder(arguments.encoder)
    words["novel"] = novel_words(tokenizer, seeded_words())
    with open(arguments.rooms) as source:
        rooms = [json.loads(row) for row in source]
    random.Random(arguments.seed).shuffle(rooms)
    cut = max(1, int(len(rooms) * arguments.held_out))
    held, train_rooms = rooms[:cut], rooms[cut:]
    held_examples = examples_for(held, words, arguments.seed - 1, arguments.per_room)
    live = live_examples(arguments.live, arguments.live_repeat) if arguments.live else []
    # EACH PURCHASE SPLIT BY ITS OWN ROOMS, so adding a second file leaves the
    # first file's held-out rooms exactly what they were without it.
    paid, paid_held, paid_held_by_file = [], [], {}
    for path in arguments.paid:
        trained, scored_only = paid_examples(path, arguments.paid_held_out, arguments.seed,
                                             {room["room"] for room in held})
        paid += trained
        paid_held += scored_only
        paid_held_by_file[path] = scored_only
    live += paid * arguments.paid_repeat

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
           "live_rows": (len(live) - len(paid) * arguments.paid_repeat) // max(1, arguments.live_repeat),
           "paid_rows": len(paid), "paid_held_out_rows": len(paid_held), "epochs": []}
    step, minutes, running = 0, 0.0, {}
    checkpoint = os.path.join(arguments.out, "checkpoint.pt")
    if os.path.exists(checkpoint):
        saved = torch.load(checkpoint, map_location="cpu", weights_only=False)
        model.load_state_dict(saved["model"])
        optimizer.load_state_dict(saved["optimizer"])
        schedule.load_state_dict(saved["schedule"])
        step, minutes, running, log["epochs"] = saved["step"], saved["minutes"], saved["running"], saved["epochs"]
        print(json.dumps({"resumed": checkpoint, "step": step}), flush=True)
    print(json.dumps({"train_rooms": len(train_rooms), "held_out_rooms": len(held), "steps": steps,
                      "micro_batch": arguments.micro}), flush=True)
    model.train()
    started = time.time() - minutes * 60

    def keep():
        os.makedirs(arguments.out, exist_ok=True)
        torch.save({"model": model.state_dict(), "optimizer": optimizer.state_dict(), "schedule": schedule.state_dict(),
                    "step": step, "minutes": (time.time() - started) / 60, "running": running,
                    "epochs": log["epochs"]}, checkpoint + ".tmp")
        os.replace(checkpoint + ".tmp", checkpoint)

    for epoch in range(step // per_epoch, arguments.epochs):
        examples = examples_for(train_rooms, words, arguments.seed + epoch, arguments.per_room) + live
        random.Random(arguments.seed + 100 + epoch).shuffle(examples)
        for start in range((step - epoch * per_epoch) * arguments.batch, len(examples), arguments.batch):
            chunk = examples[start: start + arguments.batch]
            optimizer.zero_grad()
            parts_sum = {}
            # THE SAME EFFECTIVE BATCH IN SMALLER PIECES, so a step's
            # activations are a quarter of the size and the gradient is the
            # same weighted mean.
            for piece in range(0, len(chunk), arguments.micro):
                micro = chunk[piece: piece + arguments.micro]
                ids, mask, pool, keys = batch(tokenizer, [(e["state"], e["line"]) for e in micro])
                parts = losses(model(ids, mask, pool), micro, keys)
                loss = parts["intent"] + parts["target"] + 0.5 * parts["also"] + 0.5 * parts["noul"]
                (loss * len(micro) / len(chunk)).backward()
                for name, value in parts.items():
                    parts_sum[name] = parts_sum.get(name, 0.0) + float(value) * len(micro) / len(chunk)
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()
            schedule.step()
            step += 1
            for name, value in parts_sum.items():
                running[name] = running.get(name, 0.0) * 0.98 + value * 0.02
            if step % 100 == 0:
                print(json.dumps({"epoch": epoch, "step": step, "of": steps, "minutes": round((time.time() - started) / 60, 1),
                                  **{k: round(v, 4) for k, v in running.items()}}), flush=True)
            if step % arguments.checkpoint_every == 0:
                keep()
        scored = score(model, tokenizer, held_examples)
        log["epochs"].append({"epoch": epoch, "held_out": scored, "minutes": round((time.time() - started) / 60, 1)})
        if paid_held:
            log["epochs"][-1]["paid_held_out"] = score(model, tokenizer, paid_held)
        if len(paid_held_by_file) > 1:
            log["epochs"][-1]["paid_held_out_by_file"] = {
                path: score(model, tokenizer, rows) for path, rows in paid_held_by_file.items() if rows}
        print(json.dumps(log["epochs"][-1]), flush=True)
        save(model, tokenizer, arguments.out, log)
        keep()
    print(json.dumps({"saved": arguments.out}), flush=True)


if __name__ == "__main__":
    main()
