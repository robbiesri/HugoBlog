#!/usr/bin/env python3

from pathlib import Path

import click
import proselint

# Borrowed from proselint.command_line
def print_errors(filename, errors, compact=False):
    """Print the errors, resulting from lint, for filename."""

    for error in errors:
        (check, message, line, column, start, end,
            extent, severity, replacements) = error

        if compact:
            filename = "-"

        click.echo(
            filename + ":" +
            str(1 + line) + ":" +
            str(1 + column) + ": " +
            check + " " +
            message)


def main():
    md_file_paths = Path('content').rglob('*.md')

    click.echo("Running proselint...")
    for path in md_file_paths:
        f = click.open_file(path, 'r', encoding="utf-8", errors="replace")
        errors = proselint.tools.lint(f, False, Path('.proselintrc'))
        print_errors(str(path), errors)

if __name__ == '__main__':
    main()