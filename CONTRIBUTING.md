# Contributing

Cosmosis RDFT Suite welcomes careful experiments, documentation improvements, bug fixes, and new visualization or instrumentation ideas.

## Good Contributions

- Make setup easier.
- Improve documentation or examples.
- Add reproducible visual, audio, or geometry experiments.
- Preserve existing behavior unless a change is explicitly scoped.
- Keep generated outputs out of source control unless they are small curated examples.

## Development Notes

- Keep app-specific changes inside the relevant `apps/` folder.
- Put reusable helpers in `tools/` only when they are useful outside one app.
- Do not commit API keys, private data, local `.env` files, caches, virtual environments, logs, recordings, or bulky generated output.
- For Processing sketches, prefer small scoped changes and verify by opening the sketch in Processing 4.
- For Python tools, run:

```bash
python3 scripts/doctor.py
python3 -m compileall apps tools scripts
```

## Pull Requests

Please include:

- What changed.
- Why it matters.
- How it was tested.
- Screenshots, short clips, or sample outputs when visual/audio behavior changed.
