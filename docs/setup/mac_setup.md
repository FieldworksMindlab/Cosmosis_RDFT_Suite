# macOS Setup

Most launch scripts in this repository are macOS-oriented.

## Install

1. Install Processing 4.
2. Install SuperCollider for audio synth projects.
3. Install Python 3.10 or newer.
4. Optional: install TouchDesigner for the Hopf visualization kit.

## Processing Libraries

Some synth sketches use:

- `controlP5`
- `oscP5`

Install them through Processing:

```text
Sketch -> Import Library -> Manage Libraries
```

## Python

For each Python-heavy app, create a virtual environment inside that app folder:

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
```

or, where present:

```bash
python3 -m pip install -r requirements-mac.txt
```

Do not commit `.venv`.
