# The classifier on the dressed worlds

The three hand-made worlds now dress their people in worn items. A worn thing is still carried, so the model call's carried lists name the clothes, and the classifier's request identity moved from `v2:189a5ddbb7f67a32` to `v2:1114445e276715d7`. This set is that request measured. It is judged against `classifier-about-after-20261022`, the last set bought before the dressing.

- **Arm:** Jev (TypeSafe direct) in front of `mistralai/mistral-medium-3.1`, the about pair's arm and transport. The bench now names it `mistralai/mistral-medium-3.1+typesafe-direct`.
- **Run:** four repetitions of all 437 lines of today's corpus (`5cdba44d04b495a5`), eight calls in flight.
- **Code:** server branch `fm/ta-dress-people` at `3b01cb3`, with the engine pinned at `88400098a9f3ff9fba086f0cb8a1816bbeff1e05` (renderedstep/engine#88, merged).
- Every reading is kept. `offline.json` is today's floor on this corpus.

| Rep | Right |
|---|---|
| 1 | 365/437 (0.835) |
| 2 | 365/437 (0.835) |
| 3 | 364/437 (0.833) |
| 4 | 367/437 (0.840) |

No call failed. 382 readings escalated to the model call, 94 to 97 a repetition. The before side escalated 93 to 95 a repetition.

## Verdict

### Against the before side as the bench pairs them

`rake eval:classifier_compare BEFORE=classifier-about-after-20261022 AFTER=classifier-2026-10-29-dressed`:

```
  strict_accuracy      0.937 -> 0.822  WORSE    REAL (p=0.0286)
  accuracy             0.938 -> 0.835  WORSE    REAL (p=0.0286)
  intent_accuracy      0.970 -> 0.867  WORSE    REAL (p=0.0286)
  refusal_agreement    0.953 -> 0.858  WORSE    REAL (p=0.0286)
  closed_set_misses    12 -> 13  WORSE    NOISE (inside the 3.000 the unchanged runs already spanned)
  failures             0 -> 0  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  out_of_set           57 -> 77  WORSE    REAL (p=0.0286)
```

**This compares two different corpora, and the compare says so.**
- The before side scored 372 lines. Since then, 65 wear, remove, put and walk-to lines were added (`ADDED_SINCE_POINTER` in `test/lib/eval/classifier/kept_sets_test.rb`). The before side never saw them.
- The cascade is right on 60 of those lines' 260 readings.
  - 92 of the 260 are put-on and take-off lines, which the engine points at `/wear` and `/remove` without reading them (`typed_model_dress`).
- Those 65 lines are the whole of the drop. Latency is not judged, because the two sides ran at 2 and 8 calls in flight.

### On the 372 lines both sides scored

This is the verdict, and the one `kept_sets_test.rb` asserts. Each pass's figures are recomputed from its rows the way `Eval::Classifier::Bench::Pass` computes them. Checked against both sides' own figures, the recomputation agrees to the four places they are stored.

```
  accuracy           0.938 -> 0.941   NOISE        (p=0.114)
  strict_accuracy    0.937 -> 0.945   NOISE        (p=0.057)
  intent_accuracy    0.970 -> 0.976   BETTER REAL  (p=0.029)
  refusal_agreement  0.953 -> 0.953   NOISE        (p=1.0)
  closed_set_misses  12 -> 12.5       NOISE
  out_of_set         57 -> 59.5       INCONCLUSIVE (p=0.057)
```

**Not a regression.** Every accuracy figure is NOISE or better.

### The lines that moved, read by hand (right out of 4, before -> after)

Three drop lines fell to 0. All three are clothes in the carried list:
- **`unresolved-drop-coat` 4 -> 0.** "drop my coat on the floor" at `room-3` now reads `drop -> surveyor's coat`, with `target_present` at 0.84 to 0.88 where it was 0.10 to 0.13.
  - The game is right and the label is not: the surveyor's coat is now worn there, so the line resolves.
  - This is the D4 line; see below.
- **`two-names-drop-all-three` 4 -> 0.** "put everything I am carrying down on the desk" is still refused as `named_more_than_one`, so the refusal is right.
  - The pair named is now the daybook and the office coat, and the label's three accepted pairs come from the three things carried before there were clothes.
- **`grammar-it-drop` 4 -> 0.** "drop it" in `court` was the slate 4/4.
  - Now System One's `target_present` reads 0.34 to 0.35, under neither threshold, and composes it as `drop -> nothing` (unresolved).
  - Its label's `why`, "one thing carried", is no longer true: the protagonist there now carries their clothes as well as the slate.
  - This is a real change in what the cascade reads, not only a label. The game's classifier of record is the local reader (`classifier-pointer-m68-step1-20261023`), not this cascade.

The other lines that moved, either way and none about clothes:

| Line | Before -> after |
|---|---|
| `two-names-move-office` | 4 -> 2 |
| `other-impossible` | 1 -> 0 |
| `unresolved-take-carried` | 4 -> 3 |
| `move-third-stair` | 3 -> 4 |
| `real-what-is-on-my-desk` | 3 -> 4 |
| `unresolved-talk-landlord` | 0 -> 2 |
| `unresolved-attack-inspectorate` | 0 -> 3 |
| `real-give-him-the-index` | 0 -> 4 |
| `two-names-examine-three` | 0 -> 4 |
| `grammar-repeat` | 0 -> 4 |
| `grammar-empty-ish` | 0 -> 4 |

`two-names-examine-three` is the line the about pair's README named as having moved the wrong way. It is back.

## The corpus lines the dressing made untrue (D4)

By decision (D4a), this set was measured on the corpus as it stands, and the corpus is relabelled in a follow-up that buys its own classifier set. These are the lines whose label or `why` in `test/fixtures/files/classifier_corpus.yml` the clothes made untrue:

- **`unresolved-drop-coat`** (`room-3`).
  - Its `why`, "empty hands in a world with no items at all", is false: the surveyor's coat is worn there.
  - Its label (`drop -> nothing`, `unresolved`) is now wrong, and this set reads the coat 4/4.
- **The `office-empty-handed` position, and its line `unresolved-drop-empty-hands`.**
  - The position existed to reach `Playthrough::Refusal::EMPTY`. It is not empty-handed any more, because the office coat and spectacles are worn.
  - The line still scores right (4/4 here), but the refusal it now earns is the MISSED sentence listing the clothes, not EMPTY. Its `why` ("the refusal is EMPTY, not MISSED") is false.
  - No corpus position reaches the EMPTY refusal until the relabel.
- **The `why` of `real-take-seal-from-rowe`.**
  - "the seal is not an `items` row at all" is false: Halkett Rowe now wears it as one.
  - The label is still right (4/4 here), for the other reason the `why` gives: `#items_here` is what is lying here, and taking from a person is another act.

Two more, found in this set's readings:
- **`two-names-drop-all-three`** (`office-carrying-three`). Its `why` says "ANY TWO OF THE THREE CARRIED". Five things are held there now, and its accepted pairs do not include the clothes.
- **`grammar-it-drop`** (`court`). Its `why` says "one thing carried", which is false. The relabel should decide whether "it" still means the slate when the only other things held are worn.

## Spend

`receipts.json` has the detail.

| | Spend |
|---|---|
| OpenRouter, 382 escalated model calls | **$0.108208**: the key's settled usage before and after the run. The bench keeps no per-call OpenRouter receipt; the key is shared, so this is an upper bound. Cap $0.25. |
| System One, 1,657 requests | **$0.263987**, booked off TypeSafe's reported receipts. 1,656 of them are on the readings; the warm-up's receipt, $0.000173, is not kept. Cap $0.30. |

An earlier start under `CAP=0.15` stopped at that cap after two of four repetitions and was discarded. It cost $0.095401 on OpenRouter and $0.149888 on System One, and none of it is in this set.

```sh
rake eval:classifier_compare BEFORE=classifier-about-after-20261022 AFTER=classifier-2026-10-29-dressed
```
