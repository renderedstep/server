"""The pointer-head classifier: one encoder pass, heads that only point.

Every answer is a distribution over the options the question offered and
nothing else: an intent head over the cascade's eight intents, and for each
target question a score per offered record plus a learned `nothing`, softmaxed
over exactly the keys the engine sent. So an answer is always one of the keys
sent -- the engine's answer check still runs, and has nothing to catch.

    intent                8-way, from [CLS]
    target_<action>       per record of that action's list, plus nothing
    also_named            per record of every list, plus nothing
    named_more_than_one   sigmoid, from [CLS]
    target_present        sigmoid, from [CLS]

A record's vector is the mean of its segment's tokens, joined with [CLS] so a
record is scored against the line as well as read in context.
"""

import json
import os

import torch
import torch.nn as nn
from transformers import AutoConfig, AutoModel, AutoTokenizer

from compact import INTENTS, NOTHING, TARGET_ACTIONS, encode

NOULS = ("named_more_than_one", "target_present")


class PointerClassifier(nn.Module):
    def __init__(self, encoder):
        super().__init__()
        self.encoder = encoder
        size = encoder.config.hidden_size
        self.intent = nn.Linear(size, len(INTENTS))
        self.record = nn.Sequential(nn.Linear(3 * size, size), nn.GELU())
        self.target = nn.Linear(size, len(TARGET_ACTIONS))
        self.target_nothing = nn.Linear(size, len(TARGET_ACTIONS))
        self.also = nn.Linear(size, 1)
        self.also_nothing = nn.Linear(size, 1)
        self.nouls = nn.Linear(size, len(NOULS))

    def forward(self, ids, mask, pool):
        hidden = self.encoder(input_ids=ids, attention_mask=mask).last_hidden_state
        cls = hidden[:, 0]
        recs = torch.bmm(pool, hidden)
        joined = cls.unsqueeze(1).expand_as(recs)
        features = self.record(torch.cat([recs, joined, recs * joined], dim=-1))
        return {
            "intent": self.intent(cls),
            "target": self.target(features),
            "target_nothing": self.target_nothing(cls),
            "also": self.also(features).squeeze(-1),
            "also_nothing": self.also_nothing(cls).squeeze(-1),
            "nouls": self.nouls(cls),
        }


def batch(tokenizer, items):
    """Pads [(state, line)] into tensors; answers (ids, mask, pool, keys)."""
    encoded = [encode(tokenizer, state, line) for state, line in items]
    width = max(len(ids) for ids, _, _ in encoded)
    rows = max(1, max(len(keys) for _, keys, _ in encoded))
    ids = torch.full((len(items), width), tokenizer.pad_token_id, dtype=torch.long)
    mask = torch.zeros((len(items), width), dtype=torch.long)
    pool = torch.zeros((len(items), rows, width))
    keys = []
    for b, (row, found, spans) in enumerate(encoded):
        ids[b, : len(row)] = torch.tensor(row)
        mask[b, : len(row)] = 1
        for r, (start, end) in enumerate(spans):
            pool[b, r, start:end] = 1.0 / (end - start)
        keys.append(found)
    return ids, mask, pool, keys


def option_logits(out, b, keys, options, question):
    """The logits of one choice question over `options`, in their order.

    An option this input has no record for (a record cut for length) gets
    -inf, so it is never chosen; `nothing` is the question's own learned
    score.
    """
    if question == "also_named":
        scores, nothing = out["also"][b], out["also_nothing"][b]
    else:
        action = TARGET_ACTIONS.index(question.removeprefix("target_"))
        scores, nothing = out["target"][b, :, action], out["target_nothing"][b, action]
    index = {key: i for i, key in enumerate(keys)}
    picked = []
    for option in options:
        if option == NOTHING:
            picked.append(nothing)
        elif option in index:
            picked.append(scores[index[option]])
        else:
            picked.append(torch.tensor(float("-inf")))
    return torch.stack(picked)


def save(model, tokenizer, directory, meta):
    os.makedirs(directory, exist_ok=True)
    model.encoder.config.save_pretrained(directory)
    tokenizer.save_pretrained(directory)
    torch.save(model.state_dict(), os.path.join(directory, "pointer.pt"))
    with open(os.path.join(directory, "meta.json"), "w") as out:
        json.dump(meta, out, indent=2)


def load(directory, precision="fp32"):
    config = AutoConfig.from_pretrained(directory)
    tokenizer = AutoTokenizer.from_pretrained(directory)
    model = PointerClassifier(AutoModel.from_config(config))
    model.load_state_dict(torch.load(os.path.join(directory, "pointer.pt"), map_location="cpu"))
    model.eval()
    if precision == "int8":
        model = torch.ao.quantization.quantize_dynamic(model, {nn.Linear}, dtype=torch.qint8)
    elif precision != "fp32":
        raise ValueError(f"precision is fp32 or int8, not {precision}")
    return model, tokenizer


def encoder(name):
    return AutoModel.from_pretrained(name), AutoTokenizer.from_pretrained(name)
