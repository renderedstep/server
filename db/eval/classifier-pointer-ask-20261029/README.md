# The classifier of record: the local reader, asking when it is unsure

The baseline every later classifier change is judged against. It is the
small pointer model play reads every free-typed line through
(`PointerClassifierAgent`), read by the engine's own local composition, under
the owner's ruling of 2026-10-29: *"always refuse and ask, we should track
refusals so we can try to improve the model with them in the future"*. Below
0.9 on the act it picked or on the thing it picked for that act, the line is
refused as `unsure`, nothing is played, and the reader's guess is offered back
as a slash line to type. The bench scores an ask by its ask rule: right exactly
where the line's label earns a refusal (`Eval::Classifier::Bench::Reading
#asked?`).

- **Arm:** `pointer:local`, the running sidecar (`bin/pointer-classifier`),
  asked over HTTP with the engine's own request.
- **Weights:** `pointer-032123780e5fb34c` (m68-step1), at fp32 on one
  thread. The weights are not in this repository.
- **Run:** four repetitions of all 437 lines at corpus `5cdba44d04b495a5`,
  request identity `v2:1114445e276715d7`, eight calls in flight.
- **Code:** server `d04e4c6` (`fm/ta-refuse-ask` before its rebase onto
  main, which moved only `VISION.md`), engine
  `e4800774cf03c16f69678ab020c6152edbfc163b` (renderedstep/engine#89's head
  then). The pin then moved to `c75d9ae`, which changes only how one parity
  script is stored and the engine's CI, and then to `10daa87`, the PR's
  merge commit, which changes only the engine's CI, so no reading moves.
- Every reading is kept. Free: no key, no model call, nothing spent.

## Figures

```
  strict_accuracy      0.749   the whole answer right, over unarguable lines
  accuracy             0.767   335 of 437
  intent_accuracy      0.803
  refusal_agreement    0.831
  closed_set_misses    16
  out_of_set           64
  latency_median       0.14s..0.15s
  latency_p95          0.22s
  failures             0
  asks                 23 a repetition, 10 of them where the label earns a refusal
```

The four repetitions are identical, reading for reading. Which reader
answered, each repetition: `typed_model` 383, `typed_model_unsure` 23 (asked
about), `typed_model_dress` 23, `typed_model_throw` 8.

## Against the same reader before the ruling

`rake eval:classifier_compare BEFORE=classifier-pointer-2026-10-29-dressed
AFTER=classifier-pointer-ask-20261029`, the same weights, corpus, request and
concurrency either side:

```
  strict_accuracy      0.749 -> 0.749  unchanged NOISE
  accuracy             0.764 -> 0.767  BETTER   REAL (p=0.0286)
  intent_accuracy      0.819 -> 0.803  WORSE    REAL (p=0.0286)
  refusal_agreement    0.839 -> 0.831  WORSE    REAL (p=0.0286)
  closed_set_misses    24 -> 16  BETTER   REAL (p=0.0286)
  latency_median       0.15s -> 0.15s  NOISE
  latency_p95          0.22s -> 0.22s  NOISE
  failures             0 -> 0  unchanged NOISE
  out_of_set           64 -> 64  unchanged NOISE
  asks                 -- -> 92 (40 right)
```

**Read the REAL verdicts as one line each, not as a trend.** The reader is
deterministic, so four identical repetitions a side make any difference REAL
at the smallest p four a side can reach. The whole change is 23 lines, each
of them an ask, and nothing else moved:

- **9 asks stopped a wrong act** (right now, wrong before): "approach Brace"
  no longer attacks Ammon Brace; "approach the desk" no longer takes the desk;
  "walk over to the hearth", "go out through the skylight" and "get up and
  close your door" no longer walk into Mournwell Lane; "ask Neb what the water
  did" no longer talks to Ammon Brace; "put everything I am carrying down on
  the desk" no longer drops the daybook alone; "take them" no longer takes the
  index alone; "reach into the gap in the ledger and pull the missing hour back
  out" is no longer narrated. A tenth ask, "pull my hood up", is right either
  way: its label accepts a refusal or a narration.
- **8 asks cost a line that was right:** "set it down where the Justicar can
  read it", "size up Neb's reach before anything happens", "crouch down and
  read what is chalked on the slate", "Old Grenn", "take that one on the lowest
  shelf", "count the tins of sealing wax", "is there anything I can pickup?"
  and "does he need anything else? I'm trying to work". In each, the guess
  offered back is the label's own answer, one line away.
- **5 asks were on lines already wrong** and stay wrong by the ask rule, since
  their labels want them played: "watch both of them without saying
  anything", "smell the wax and the old ink", "go down the stairs and out into
  Mournwell Lane", "Rowe, I want the supporting file for the boundary" and "go
  through the clerk's desk", whose guess walked to The Beech Clearing.

So `accuracy` gains one line net; `closed_set_misses` falls because an ask is
never a wrong record; `intent_accuracy` and `refusal_agreement` fall because
an ask on a line to be played is scored wrong on both. This is the shape the
decision card of 2026-10-29 priced option B at (335 of 437 on the corpus
before the dressing).

## What not to do with it

Do not tune the 0.9 against this corpus: that would fit the yardstick, not
the game. It is checked against the lines play keeps (`RefusedLine`).
