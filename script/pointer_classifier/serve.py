"""Answers cascade requests with the pointer model.

    python serve.py <model dir> [--precision fp32|int8] [--threads N]
    python serve.py <model dir> --http PORT [--precision ...] [--threads N]

ON STDIN (the bench's child process, `Eval::Classifier::Pointer`): prints
`{"ready": true}` once the model is loaded, then for every request line --
`{"state": {...}, "questions": {id: [option keys] | null}}`, a null being a
yes/no question -- prints Jev's body shape, `{"answers": {id: ...}}`. A
question this model was not trained for is refused with `{"error": ...}`,
which the caller treats as System One being unavailable.

OVER HTTP (the classifier's local reader in play, `PointerClassifierAgent`):
listens on 127.0.0.1:PORT only, and answers a POST of System One's own body,
`{"model", "state", "questions"}` with Jev-typed questions (`{"type": "noul"}`
or `{"type": "choice", "criteria": {key: text}}`), with
`{"answers": ..., "usage": {"cost": 0}}`. Until the model is loaded it answers
503, so a turn played during a start is refused at once rather than waiting
out its timeout; a request it cannot answer is a 422 with `{"error": ...}`.
One request is answered at a time, on one model. `GET /` says whether it is
ready. `model` is the weights' digest, which the engine records; it is not read.

It reads nothing but the request and the model directory, and opens no
network connection of its own.
"""

import argparse
import json
import os
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

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


def compact_questions(questions):
    """Jev's typed questions as this model reads them: a choice's option keys,
    or null for a yes/no question."""
    compact = {}
    for question, typed in questions.items():
        if typed.get("type") == "noul":
            compact[question] = None
        elif typed.get("type") == "choice":
            compact[question] = list(typed["criteria"].keys())
        else:
            raise ValueError(f"{question} is neither a noul nor a choice")
    return compact


def serve_http(arguments):
    loaded = {}
    lock = threading.Lock()

    class Handler(BaseHTTPRequestHandler):
        def reply(self, status, body):
            data = json.dumps(body).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):  # noqa: N802 -- the standard library's name
            if "model" not in loaded:
                return self.reply(503, {"ready": False})
            self.reply(200, {"ready": True})

        def do_POST(self):  # noqa: N802
            length = int(self.headers.get("Content-Length") or 0)
            body = self.rfile.read(length)
            if "model" not in loaded:
                return self.reply(503, {"error": "the model is still loading"})
            try:
                request = json.loads(body)
                compact = {"state": request["state"], "questions": compact_questions(request["questions"])}
                with lock:
                    reply = answer(loaded["model"], loaded["tokenizer"], compact)
            except Exception as error:  # noqa: BLE001 -- any failure is one refused request
                return self.reply(422, {"error": f"{type(error).__name__}: {error}"})
            reply["usage"] = {"cost": 0}
            self.reply(200, reply)

        def log_message(self, format, *args):  # noqa: A002 -- one line per request is noise
            pass

    server = ThreadingHTTPServer(("127.0.0.1", arguments.http), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    print(f"pointer classifier: listening on 127.0.0.1:{arguments.http}, loading {arguments.directory}",
          file=sys.stderr, flush=True)
    model, tokenizer = load(arguments.directory, arguments.precision)
    loaded.update(model=model, tokenizer=tokenizer)
    print("pointer classifier: ready", file=sys.stderr, flush=True)
    try:
        threading.Event().wait()
    except KeyboardInterrupt:
        pass
    finally:
        server.shutdown()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("directory")
    parser.add_argument("--precision", default="fp32")
    parser.add_argument("--threads", type=int, default=1)
    parser.add_argument("--http", type=int, metavar="PORT")
    arguments = parser.parse_args()
    torch.set_num_threads(arguments.threads)
    if arguments.http:
        return serve_http(arguments)
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
