# The talk-about-another pair, before: today's System One wording on the relabelled corpus

Setup:
- **Arm:** Jev 1.13 (TypeSafe direct) in front of `mistralai/mistral-medium-3.1`.
- **Run:** four repetitions of all 372 lines at corpus digest `987e6b7fb383ccc2`, two calls in flight.
- **Request identity:** `v2:189a5ddbb7f67a32`.
- Every reading is kept.

It was bought at server `0284974`, with the engine at `08b9b635f6823ecff78d18eaf36b6ff16a0254ae`. That engine's System One wording still tells the reader to count both people when one is addressed and the other appears inside the message.

## Why it was re-bought

The owner ruled that on a talk, only the people the player is speaking to count. The corpus changed with the ruling, and so did its digest:
- `two-names-talk-perrin` now plays as a talk to Perrin.
- Six lines joined it under the `talk-about-another` shape: five that play and one control that speaks to both people and is refused.

So no earlier set is a matched before side for that ruling.

## What it reads

**The two-listener lines hold.** All five (`two-names-talk-two-people`, `-both`, `-court`, `-court-full`, `-court-and`) and the new control are refused 4/4.

**Five of the six lines that should play already do, 4/4.** System One flags every one of them: its two-name reading is 0.63 to 0.86, so each line goes on to the model call, and the model call reads one talk.

**"Rowe, is Perrin telling the truth?" is 0/4.** The model call names Perrin as a second person, so the line is refused.

Escalations: 99 to 102 lines a repetition.

## Spend

Booked from provider-reported charges on every settled call (`receipts.json`):
- **$0.173630** for this set's 403 escalations.
- **$0.037184** for an aborted first start that ran both default arms by mistake: 72 settled calls, stopped and not kept.
- **$0.210814** in all.

No call was unsettled, and the highest single charge was $0.0006064.

OpenRouter credit readings, taken from inside the bench process, bracket the kept run at $0.163553 and the aborted start at $0.028763. Receipts are the figure of record. The System One requests are unreceipted, as on every cascade set.

The spend guard was the use pair's: one ledger shared by both sides under a $0.40 cap, a reservation of $0.006 a call, and transport retries off.
