#!/usr/bin/env bash
set -eu
python -m pip install -r requirements.txt
python -m unittest discover -s tests
