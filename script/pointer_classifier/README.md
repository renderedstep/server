# The pointer classifier

A small local model (Ettin-17M with a pointer head) that answers the
classifier's System One request in Jev's place. The design, and what the
bench arm does with an escalated line, are in the header of
`lib/eval/classifier/pointer.rb`; this file is only how to build one.

Nothing here makes a model call or needs a key, except the optional paid step
2b below. Keep both System One keys out of the shell anyway (`unset
OPENROUTER_API_KEY TYPESAFE_API_KEY`): either one turns the cascade on for
anything else you run beside this. Give the key to step 2b's two commands only.

**Everything this writes stays outside the repository** — rooms, the owner's
lines, weights and bench sets are data, and the repository is public. `$DATA`
below is any directory outside it.

```bash
# 0. A CPU-only Python environment beside the data.
uv venv --python 3.12 $DATA/venv
VIRTUAL_ENV=$DATA/venv uv pip install --index-url https://download.pytorch.org/whl/cpu torch
VIRTUAL_ENV=$DATA/venv uv pip install -r script/pointer_classifier/requirements.txt

# 1. Generated rooms, staged offline by the engine (never the seeded worlds).
OUT=$DATA/rooms COUNT=2400 SEED=20261015 bin/rails eval:pointer_rooms

# 2. Optional: the owner's own model-read lines, from a COPY of the database.
sqlite3 'file:storage/development.sqlite3?mode=ro' ".backup $DATA/owner-copy.sqlite3"
$DATA/venv/bin/python script/pointer_classifier/live_lines.py \
  $DATA/owner-copy.sqlite3 test/fixtures/files/classifier_corpus.yml $DATA/live.jsonl

# 2b. Optional and PAID: a chat model writes lines for some of the rooms, and the
#     classifier call labels them (`Eval::Classifier::Pointer::Paraphrases`).
#     Each step resumes, so nothing is bought twice; run a small COUNT first.
OUT=$DATA/paid ROOMS=$DATA/rooms/rooms.jsonl COUNT=80 SEED=1 bin/rails eval:pointer_paraphrases
OUT=$DATA/paid ROOMS=$DATA/rooms/rooms.jsonl bin/rails eval:pointer_labels
#     A second purchase goes in its own OUT, with SHAPE=play (whole sentences,
#     attacks, absent names, plain named exits, few attempts) and
#     EXCLUDE=$DATA/paid/written.jsonl so it writes for rooms the first did not.

# 3. Train (CPU; about an hour on 8 threads of a busy laptop, ~3 GB of memory).
#    It checkpoints every 50 steps; run the same command again to resume.
#    Add `--paid $DATA/paid/labels.jsonl` if step 2b was run, once per purchase.
$DATA/venv/bin/python script/pointer_classifier/train.py \
  --rooms $DATA/rooms/rooms.jsonl --live $DATA/live.jsonl --out $DATA/model

# 4. Bench it against the 354 hand labels, fp32 and int8, one core each.
MODELS=pointer:$DATA/model,pointer:$DATA/model+int8 REPS=4 SET=pointer-<date> bin/rails eval:classifier

# 5. The model's own time per line.
$DATA/venv/bin/python script/pointer_classifier/latency.py $DATA/model $DATA/rooms/rooms.jsonl --threads 1
```

The bench finds Python at `$DATA/venv/bin/python` beside the model directory,
or wherever `POINTER_PYTHON` points; `POINTER_THREADS` (default 1) is how many
threads the model may use.

The free labels are built, not bought: `templates.py` writes lines into the
staged rooms and labels each by how it was written, and `live_lines.py` takes
the owner's lines that the classifier model read alone. The paid labels of
step 2b are the classifier call's own readings, with no System One request
made. No line Jev read — and no stored Jev answer of any kind — is used,
because TypeSafe's terms forbid training on its outputs.
