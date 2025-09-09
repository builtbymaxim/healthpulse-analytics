"""Test package configuration.

Ensures the project root is available on ``sys.path`` so that modules like
``data_generator`` and ``ml_models`` can be imported during tests regardless of
the working directory from which pytest is invoked.
"""

import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

