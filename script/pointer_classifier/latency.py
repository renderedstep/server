"""The model's own time per line, on a stated number of threads.

    python latency.py <model dir> <rooms.jsonl> [--threads 1] [--lines 300]

One forward pass per line, the way `serve.py` answers one request, over lines
written into staged rooms; the first few are a warm-up and are not counted.
`rake eval:classifier` times the whole read instead -- the engine building
the request, the pipe, the model and the engine composing the answer -- and
both figures are worth having: this one is the model, that one is the turn.
"""

import argparse
import json
import os
import random
import statistics
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import torch  # noqa: E402

from model import batch, load  # noqa: E402
from templates import lines_for, vocabulary  # noqa: E402

WARMUP = 10


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("directory")
    parser.add_argument("rooms")
    parser.add_argument("--threads", type=int, default=1)
    parser.add_argument("--lines", type=int, default=300)
    arguments = parser.parse_args()
    torch.set_num_threads(arguments.threads)

    words, rng = vocabulary(), random.Random(7)
    with open(arguments.rooms) as source:
        rooms = [json.loads(row) for row in source][-200:]
    items = []
    for room in rooms:
        items += [(room["state"], line) for line, _ in lines_for(room["state"], words, rng, 2)]
    items = items[: arguments.lines + WARMUP]

    report = {"threads": arguments.threads, "lines": len(items) - WARMUP}
    for precision in ("fp32", "int8"):
        model, tokenizer = load(arguments.directory, precision)
        times, lengths = [], []
        with torch.inference_mode():
            for n, item in enumerate(items):
                started = time.perf_counter()
                ids, mask, pool, _ = batch(tokenizer, [item])
                model(ids, mask, pool)
                if n >= WARMUP:
                    times.append(time.perf_counter() - started)
                    lengths.append(ids.shape[1])
        times.sort()
        report[precision] = {
            "median_ms": round(statistics.median(times) * 1000, 2),
            "p95_ms": round(times[int(len(times) * 0.95) - 1] * 1000, 2),
            "tokens_median": statistics.median(lengths),
            "tokens_max": max(lengths),
        }
    report["torch"] = torch.__version__
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
