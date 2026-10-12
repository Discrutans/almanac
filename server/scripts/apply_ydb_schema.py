#!/usr/bin/env python3
"""Apply YDB schema from schema.yql."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from almanac.db.ydb_driver import apply_schema, close_pool


def main() -> None:
    apply_schema()
    close_pool()
    print("YDB schema applied.")


if __name__ == "__main__":
    main()
