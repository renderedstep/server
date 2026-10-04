# Typed volition decision with the speech question: 12 staged rooms x 4 repetitions

`rake eval:volition_baseline ROOMS=speech CAP=0.01 SET=volition-speech-baseline-20261004`
sent each of the twelve staged rooms in `requests.json` to TypeSafe directly
(`jev-1.13.0`, on `TYPESAFE_API_KEY`) four times, under a 0.01 USD ceiling
that stops rather than exceeds. All 48 calls answered 200.

`requests.json` is a copy of
`test/fixtures/files/volition_speech_baseline_requests.json` as it was sent:
the rooms of `volition-baseline-20260926`, with the same people, state and
act, serves and pressure questions byte for byte
(`Playthrough::Volition::BaselineRoomsTest` checks that), and beside them a
`:speech` question for everybody who has somebody to say something to, as
though the speech die had let them speak. That is the request an arrival sends
for the people reacting to it. Ten of the twelve rooms ask it; in
`hallway-grenn-alone` and `tidepost-neb-alone` the player stands elsewhere,
so nothing may be said and those two requests are the act requests unchanged.
The player carries nothing and no room has a hazard, so every speech question
offers the same three options: "Say nothing.", a greeting and telling the
player to leave.

`rake eval:volition_baseline_summary SET=volition-speech-baseline-20261004`
prints the full per-room summary for free; `Eval::VolitionSpeechBaselineTest`
pins the headline figures below.

## Cost

- 48 calls, 44,148 input tokens: 0.001854216 USD at TypeSafe's published
  0.042 USD per million input tokens (output is not charged), 0.000038630 per
  call. TypeSafe reports tokens, not a price, so this is the receipts' tokens
  at that rate; there is no credit reading for this transport.
- The same rooms without the speech question cost 0.001683864 over OpenRouter
  in `volition-baseline-20260926`, at the same rate per input token (785 input
  tokens there priced at 0.00003297, exactly 785 at 0.042 per million). The
  speech question adds about 10% to a call.

## What it shows, against `volition-baseline-20260926`

The transport differs (TypeSafe direct here, OpenRouter Decisions there) and
the Jev release is the same (`jev-1.13.0`, `typesafe/jev-1.13`). The one
change to the requests is the speech question.

- **The act answers did not move.** Every person chose the same act on the
  same repetitions as before but one, and that one is the same split: Perrin
  Lasco in Ward Office 12 gave the player his private index on two of four
  repetitions and stayed put on two, as before (in a different order). The
  shapes chosen are the same 38 waits, 8 walks out, 8 pick-ups and 2 gives
  of 56 answers.
- **Serves did not move**: every person's serves answer is the one they gave
  before.
- **Pressure did not move** beyond its own noise: every person's mean is
  within 0.01 of before (mean 0.630, range 0.44 to 0.85, at or over 0.5 in 48
  of 56 answers, as before).
- **What they said was mostly nothing.** Of 48 speech answers, 36 were "Say
  nothing." and 12 a greeting; nobody told the player to leave. The greetings
  are three people, each on all four repetitions: Ammon Brace and Neb Halloran
  together in the Causeway Court, and Perrin Lasco following the player in the
  supply closet. Every person gave the same speech answer on every repetition.
  In play the die has already decided that somebody speaks before this
  question is asked, so a "Say nothing." here is the typed judgment taking the
  words back: that person then takes their act instead.
