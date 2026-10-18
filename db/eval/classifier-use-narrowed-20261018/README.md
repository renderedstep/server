# The use pair, narrowed: System One's `use` tied to a fixed piece named in `physical_actions`

The same arm, transport, corpus and repetitions as the use pair
(`classifier-use-before-20261018`, `classifier-use-after-20261018`): Jev 1.13
(TypeSafe direct) in front of `mistralai/mistral-medium-3.1`, four repetitions
of all 366 lines at `0be7d3a93c05f097`, two calls in flight. Every reading is
kept.

It was bought at server `80f5da6`, with the engine at renderedstep/engine#64's
head `92ca2c3259eada3def54e3979a17e7f3f769bdd3`. That engine differs from the
use pair's after side only in System One's `use` criterion and target premise:

```
after:    ...offer a carried item, open a barrier, or search, open or break a part off something fixed here.
narrowed: ...offer a carried item, or open a barrier, or to search, open or break a part off a fixed piece named in `physical_actions`.
```

The model call's instructions are text C, unchanged, so the request identity
(`v2:189a5ddbb7f67a32`) is the after side's. The System One request is in no
digest.

## Verdicts

Against `classifier-use-before-20261018`, the description before text C:

```
  strict_accuracy      0.924 -> 0.931  BETTER   REAL (p=0.0286)
  accuracy             0.928 -> 0.929  BETTER   NOISE
  intent_accuracy      0.975 -> 0.967  WORSE    REAL (p=0.0286)
  refusal_agreement    0.949 -> 0.950  BETTER   NOISE
  closed_set_misses    17 -> 14        BETTER   REAL (p=0.0286)
  out_of_set           55 -> 58        WORSE    REAL (p=0.0286)
```

Against `classifier-use-after-20261018`, text C: NOISE on every figure.

## Line by line

| line | before | text C | narrowed |
|---|---:|---:|---:|
| "search the desk" | 0/4 | 4/4 | 4/4 |
| "rummage through the desk drawers" | 0/4 | 4/4 | 4/4 |
| "go through the clerk's desk" | 0/4 | 4/4 | 3/4 |
| "get up and close your door" | 4/4 | 0/4 | **0/4** |
| "I am going to inventory that closet myself" | 4/4 | 1/4 | **4/4** |
| "stamp" | 4/4 | 0/4 | **4/4** |

- **The narrowing keeps the searches** and recovers two of the three lines text
  C broke.
- **"get up and close your door" is still read as `use -> nothing`**, by System
  One without escalating. Its room lists no physical action at all.
- **On the 354 lines outside the study,** intent accuracy is 0.976 against
  0.969 before text C. That is INCONCLUSIVE (p=0.057).
- **Set aside "close your door" as well (353 lines),** and accuracy and intent
  accuracy are NOISE (p=0.26 and p=0.2). The rest is single readings either
  way.

The study's lines are right 43/48, against 32/48 before and 44/48 under text C.

## Spend

Booked from provider-reported charges on every settled call
(`receipts.json`): **$0.138611** for 386 Mistral calls, plus **$0.041675** for
a one-repetition trial taken first and not kept (340/366), **$0.180286** in all.
That was under a $0.25 cap, with the highest single charge $0.0006088. The
System One requests have no receipt here.

```sh
rake eval:classifier_compare BEFORE=classifier-use-before-20261018 AFTER=classifier-use-narrowed-20261018
rake eval:classifier_compare BEFORE=classifier-use-after-20261018 AFTER=classifier-use-narrowed-20261018
```
