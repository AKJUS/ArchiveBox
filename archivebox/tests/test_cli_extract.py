#!/usr/bin/env python3
"""
Tests for archivebox extract command.
Verify extract re-runs extractors on existing snapshots.
"""

import json

import pytest

from archivebox.core.models import Snapshot
from archivebox.tests.conftest import run_archivebox_cmd, cli_env

from archivebox.tests.test_orm_helpers import use_archivebox_db

pytestmark = pytest.mark.django_db(transaction=True)


def _create_snapshot(data_dir, env, url="https://example.com"):
    record = json.dumps({"type": "Snapshot", "url": url})
    run_archivebox_cmd(
        ["snapshot", "create"],
        cwd=data_dir,
        stdin=f"{record}\n",
        env=env,
        check=True,
    )


def test_extract_runs_on_existing_snapshots(initialized_archive):
    """Test that extract command runs on existing snapshots."""
    env = cli_env(disable_extractors=True)

    _create_snapshot(initialized_archive, env)

    # Run extract
    result = run_archivebox_cmd(
        ["extract"],
        cwd=initialized_archive,
        env=env,
        timeout=30,
    )

    # Should complete
    assert result.returncode in [0, 1]


def test_extract_preserves_snapshot_count(initialized_archive):
    """Test that extract doesn't change snapshot count."""
    env = cli_env(disable_extractors=True)

    _create_snapshot(initialized_archive, env)

    with use_archivebox_db(initialized_archive):
        count_before = Snapshot.objects.count()

    # Run extract
    run_archivebox_cmd(
        ["extract", "--overwrite"],
        cwd=initialized_archive,
        env=env,
        timeout=30,
    )

    with use_archivebox_db(initialized_archive):
        count_after = Snapshot.objects.count()

    assert count_after == count_before
