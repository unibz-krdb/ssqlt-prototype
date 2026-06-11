import argparse
import sys
from pathlib import Path

from .constraints import UnsupportedError
from .generator import Generator
from .transducer_context import TransducerContext


def main():
    parser = argparse.ArgumentParser(description="Semantic SQL Transducer Compiler")
    parser.add_argument("universal", help="Path to universal schema JSON")
    parser.add_argument("source", help="Path to source RA file")
    parser.add_argument("target", help="Path to target RA file")
    parser.add_argument("--output", "-o", help="Output SQL file (default: stdout)")
    parser.add_argument(
        "--comments",
        "-c",
        action="store_true",
        help="Annotate the generated SQL with explanatory comments",
    )
    args = parser.parse_args()

    try:
        ctx = TransducerContext.from_files(args.universal, args.source, args.target)
        sql = Generator(ctx, comments=args.comments).compile()
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except (ValueError, UnsupportedError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if args.output:
        Path(args.output).write_text(sql)
    else:
        sys.stdout.write(sql)


if __name__ == "__main__":
    main()
