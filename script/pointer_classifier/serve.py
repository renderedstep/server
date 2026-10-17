"""Answers cascade requests with the pointer model, one per line on stdin.

    python serve.py <model dir> [--precision fp32|int8] [--threads N]

Prints `{"ready": true}` once the model is loaded, then for every request
line -- `{"state": {...}, "questions": {id: [option keys] | null}}`, a null
being a yes/no question -- prints Jev's body shape, `{"answers": {id: ...}}`.
A question this model was not trained for is refused with `{"error": ...}`,
which the caller treats as System One being unavailable. Run by
`Eval::Classifier::Pointer`; it reads nothing but the request and the model
directory, and opens no network connection.
"""

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import torch  # noqa: E402

from compact import INTENTS  # noqa: E402
from model import NOULS, batch, load, option_logits  # noqa: E402


def answer(model, tokenizer, request):
    state, questions = request["state"], request["questions"]
    with torch.inference_mode():
        ids, mask, pool, keys = batch(tokenizer, [(state, None)])
        out = model(ids, mask, pool)
    answers = {}
    for question, options in questions.items():
        if options is None:
            if question not in NOULS:
                raise ValueError(f"not trained to answer the yes/no question {question}")
            yes = torch.sigmoid(out["nouls"][0, NOULS.index(question)]).item()
            answers[question] = {"type": "noul", "noul": yes}
            continue
        if question == "intent":
            logits = torch.stack([
                out["intent"][0, INTENTS.index(option)] if option in INTENTS else torch.tensor(float("-inf"))
                for option in options
            ])
        elif question == "also_named" or question.startswith("target_"):
            logits = option_logits(out, 0, keys[0], options, question)
        else:
            raise ValueError(f"not trained to answer {question}")
        probabilities = torch.softmax(logits, dim=0)
        chosen = int(torch.argmax(probabilities))
        answers[question] = {
            "type": "choice",
            "choice": options[chosen],
            "probabilities": {option: round(p, 6) for option, p in zip(options, probabilities.tolist())},
        }
    return {"answers": answers}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("directory")
    parser.add_argument("--precision", default="fp32")
    parser.add_argument("--threads", type=int, default=1)
    arguments = parser.parse_args()
    torch.set_num_threads(arguments.threads)
    model, tokenizer = load(arguments.directory, arguments.precision)
    print(json.dumps({"ready": True}), flush=True)
    for line in sys.stdin:
        if not line.strip():
            continue
        try:
            reply = answer(model, tokenizer, json.loads(line))
        except Exception as error:  # noqa: BLE001 -- any failure is one refused request
            reply = {"error": f"{type(error).__name__}: {error}"}
        print(json.dumps(reply), flush=True)


if __name__ == "__main__":
    main()
