#!/usr/bin/env python3
"""
LinkStack backup / restore — snapshot the /htdocs data volume.

Because the BAUER GROUP LinkStack stack uses SQLite, the ENTIRE application state
(SQLite database, uploaded images, installed themes and /htdocs/.env) lives in a
single named Docker volume: ``${STACK_NAME}-data``. This tool tars that volume to
a gzip archive and restores it — no database dump needed.

Zero third-party dependencies (Python 3.6+ stdlib only). It shells out to Docker
and uses a throwaway helper container to read/write the volume.

Examples
--------
    python scripts/linkstack-backup.py backup
    python scripts/linkstack-backup.py backup --stack linkstack --stop
    python scripts/linkstack-backup.py list
    python scripts/linkstack-backup.py restore linkstack-backup-20260716-101500.tar.gz --stop

For a *consistent* SQLite snapshot, pass ``--stop`` so the app container is
stopped for the duration of the backup/restore and started again afterwards.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import os
import subprocess
import sys

HELPER_IMAGE_DEFAULT = "busybox:stable"


def _run(cmd, **kwargs):
    """Run a command, echoing it. Returns the CompletedProcess."""
    print("+ " + " ".join(cmd))
    return subprocess.run(cmd, **kwargs)


def _docker_ok() -> bool:
    try:
        return _run(["docker", "version", "--format", "{{.Server.Version}}"],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    except FileNotFoundError:
        return False


def _volume_exists(volume: str) -> bool:
    return _run(["docker", "volume", "inspect", volume],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def _container_running(name: str) -> bool:
    res = _run(["docker", "ps", "--filter", f"name=^{name}$", "--format", "{{.Names}}"],
               stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    return name in (res.stdout or "").split()


def _timestamp() -> str:
    return _dt.datetime.now().strftime("%Y%m%d-%H%M%S")


def _volume_name(args) -> str:
    return args.volume or f"{args.stack}-data"


def _container_name(args) -> str:
    # Matches compose: container_name: ${STACK_NAME}_SERVER
    return args.container or f"{args.stack}_SERVER"


# --------------------------------------------------------------------------- #
# Commands
# --------------------------------------------------------------------------- #
def cmd_backup(args) -> int:
    volume = _volume_name(args)
    if not _volume_exists(volume):
        print(f"ERROR: volume '{volume}' does not exist. Is the stack deployed?", file=sys.stderr)
        return 2

    out_dir = os.path.abspath(args.output_dir)
    os.makedirs(out_dir, exist_ok=True)
    fname = f"linkstack-backup-{_timestamp()}.tar.gz"
    container = _container_name(args)

    stopped = False
    if args.stop and _container_running(container):
        print(f"Stopping container '{container}' for a consistent snapshot ...")
        _run(["docker", "stop", container], stdout=subprocess.DEVNULL)
        stopped = True

    try:
        rc = _run([
            "docker", "run", "--rm",
            "-v", f"{volume}:/data:ro",
            "-v", f"{out_dir}:/backup",
            args.helper_image,
            "tar", "czf", f"/backup/{fname}", "-C", "/data", ".",
        ]).returncode
    finally:
        if stopped:
            print(f"Starting container '{container}' again ...")
            _run(["docker", "start", container], stdout=subprocess.DEVNULL)

    if rc != 0:
        print("ERROR: backup failed.", file=sys.stderr)
        return rc

    path = os.path.join(out_dir, fname)
    size = os.path.getsize(path) if os.path.exists(path) else 0
    print(f"\n✓ Backup written: {path} ({size / 1_048_576:.1f} MiB)")
    if not args.stop:
        print("  Note: taken while running — for a guaranteed-consistent SQLite "
              "snapshot, re-run with --stop.")
    return 0


def cmd_restore(args) -> int:
    archive = os.path.abspath(args.archive)
    if not os.path.isfile(archive):
        print(f"ERROR: archive not found: {archive}", file=sys.stderr)
        return 2

    volume = _volume_name(args)
    container = _container_name(args)

    if not args.yes:
        print(f"About to OVERWRITE the contents of volume '{volume}' from:\n  {archive}")
        if input("Type 'yes' to continue: ").strip().lower() != "yes":
            print("Aborted.")
            return 1

    if not _volume_exists(volume):
        print(f"Creating volume '{volume}' ...")
        _run(["docker", "volume", "create", volume], stdout=subprocess.DEVNULL)

    stopped = False
    if args.stop and _container_running(container):
        print(f"Stopping container '{container}' ...")
        _run(["docker", "stop", container], stdout=subprocess.DEVNULL)
        stopped = True

    bdir = os.path.dirname(archive)
    bname = os.path.basename(archive)
    try:
        # Wipe then extract, so the restore is exact (removes files added since).
        rc = _run([
            "docker", "run", "--rm",
            "-v", f"{volume}:/data",
            "-v", f"{bdir}:/backup:ro",
            args.helper_image,
            "sh", "-c",
            "rm -rf /data/* /data/..?* /data/.[!.]* 2>/dev/null; "
            f"tar xzf /backup/{bname} -C /data",
        ]).returncode
    finally:
        if stopped:
            print(f"Starting container '{container}' again ...")
            _run(["docker", "start", container], stdout=subprocess.DEVNULL)

    if rc != 0:
        print("ERROR: restore failed.", file=sys.stderr)
        return rc
    print(f"\n✓ Restored volume '{volume}' from {bname}")
    return 0


def cmd_list(args) -> int:
    out_dir = os.path.abspath(args.output_dir)
    if not os.path.isdir(out_dir):
        print(f"No backup directory: {out_dir}")
        return 0
    files = sorted(f for f in os.listdir(out_dir)
                   if f.startswith("linkstack-backup-") and f.endswith((".tar.gz", ".tar")))
    if not files:
        print(f"No backups in {out_dir}")
        return 0
    print(f"Backups in {out_dir}:")
    for f in files:
        size = os.path.getsize(os.path.join(out_dir, f))
        print(f"  {f}  ({size / 1_048_576:.1f} MiB)")
    return 0


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Backup / restore the LinkStack /htdocs data volume (SQLite stack).")
    p.add_argument("--stack", default=os.environ.get("STACK_NAME", "linkstack"),
                   help="STACK_NAME prefix (default: env STACK_NAME or 'linkstack').")
    p.add_argument("--volume", default=None,
                   help="Volume name override (default: <stack>-data).")
    p.add_argument("--container", default=None,
                   help="Container name override (default: <stack>_SERVER).")
    p.add_argument("--helper-image", default=HELPER_IMAGE_DEFAULT,
                   help=f"Throwaway image used for tar (default: {HELPER_IMAGE_DEFAULT}).")

    sub = p.add_subparsers(dest="command", required=True)

    b = sub.add_parser("backup", help="Create a gzip snapshot of the volume.")
    b.add_argument("-o", "--output-dir", default=".", help="Where to write the archive.")
    b.add_argument("--stop", action="store_true",
                   help="Stop the app container during backup for a consistent SQLite snapshot.")
    b.set_defaults(func=cmd_backup)

    r = sub.add_parser("restore", help="Restore the volume from an archive (overwrites).")
    r.add_argument("archive", help="Path to a linkstack-backup-*.tar.gz file.")
    r.add_argument("--stop", action="store_true",
                   help="Stop the app container during restore.")
    r.add_argument("-y", "--yes", action="store_true", help="Skip the confirmation prompt.")
    r.set_defaults(func=cmd_restore)

    l = sub.add_parser("list", help="List local backup archives.")
    l.add_argument("-o", "--output-dir", default=".", help="Directory to list.")
    l.set_defaults(func=cmd_list)

    return p


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    if not _docker_ok():
        print("ERROR: Docker is not available on PATH / daemon not running.", file=sys.stderr)
        return 2
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
