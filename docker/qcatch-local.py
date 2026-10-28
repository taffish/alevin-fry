#!/opt/qcatch/bin/python3
"""Run unmodified QCatch with explicit local inputs and private writable caches."""
import argparse
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time


def main():
    argv = sys.argv[1:]
    probe = argparse.ArgumentParser(add_help=False, allow_abbrev=False)
    probe.add_argument('--input', '-i')
    probe.add_argument('--output', '-o')
    probe.add_argument('--gene_id2name_file', '-g')
    args, _ = probe.parse_known_args(argv)
    informational = any(x in argv for x in ('--help', '-h', '--version', '-v'))
    if not informational:
        if not args.gene_id2name_file:
            raise ValueError('TAFFISH requires --gene_id2name_file with a local authorized TSV; implicit registry downloads are disabled.')
        mapping = Path(args.gene_id2name_file)
        if not mapping.is_file() or not mapping.stat().st_size:
            raise ValueError('local gene ID/name mapping is missing or empty')
        seen = set()
        with mapping.open(encoding='utf-8') as source:
            for row in source:
                fields = row.rstrip('\n').split('\t')
                if len(fields) != 2 or not all(fields) or '\r' in row or fields[0] in seen:
                    raise ValueError('mapping must have unique gene IDs and two nonempty TSV columns, without header or CRLF')
                seen.add(fields[0])
        if not args.input or not args.output:
            raise ValueError('TAFFISH requires explicit --input and --output; use a separate output directory to preserve input')
        source, output = Path(args.input).resolve(), Path(args.output).resolve()
        if output == source or (source.is_file() and output == source.parent):
            raise ValueError('output must differ from the input directory; in-place input modification is disabled')
    elif '--help' in argv or '-h' in argv:
        print('TAFFISH packaging: explicit local --gene_id2name_file and separate --output are required.\n'
              'No implicit downloads. qcatch-offline creates a separate standalone copy of the native report.', flush=True)
    # A private per-invocation cache supports arbitrary UID and read-only SIF/OCI.
    child = None
    caught = 0
    stop_at = None
    previous = {}

    def forward(signum, _frame):
        nonlocal caught, stop_at
        caught = signum
        if stop_at is None:
            stop_at = time.monotonic() + 5
        if child is not None and child.poll() is None:
            try:
                os.killpg(child.pid, signum)
            except ProcessLookupError:
                pass

    # Defer signals even across creation/assignment of the private cache owner.
    # No untracked directory is left if termination arrives immediately after mkdir.
    for sig in (signal.SIGINT, signal.SIGTERM):
        previous[sig] = signal.signal(sig, forward)
    try:
        with tempfile.TemporaryDirectory(prefix='taffish-qcatch-') as cache:
            env = dict(os.environ, MPLCONFIGDIR=cache + '/mpl', NUMBA_CACHE_DIR=cache + '/numba',
                       XDG_CACHE_HOME=cache, PYTHONDONTWRITEBYTECODE='1')
            try:
                if caught:
                    return 128 + caught
                child = subprocess.Popen(['/opt/qcatch/bin/qcatch'] + argv, env=env, start_new_session=True)
                if caught:
                    forward(caught, None)
                while True:
                    try:
                        code = child.wait(timeout=0.2)
                        break
                    except subprocess.TimeoutExpired:
                        if stop_at is not None and time.monotonic() >= stop_at:
                            try:
                                os.killpg(child.pid, signal.SIGKILL)
                            except ProcessLookupError:
                                pass
                return 128 + caught if caught else (128 - code if code < 0 else code)
            finally:
                # Stop the owned process group before the cache context is removed.
                if child is not None:
                    try:
                        os.killpg(child.pid, signal.SIGTERM)
                        if child.poll() is None:
                            child.wait(timeout=5)
                    except (ProcessLookupError, subprocess.TimeoutExpired):
                        if child.poll() is None:
                            os.killpg(child.pid, signal.SIGKILL)
                            child.wait()
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError) as error:
        print('qcatch: ' + str(error), file=sys.stderr)
        sys.exit(2)
