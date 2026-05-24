from datetime import datetime
from typing import cast

import pytest
from django.contrib.auth import get_user_model
from django.contrib.auth.models import UserManager
from django.utils import timezone


pytestmark = pytest.mark.django_db


User = get_user_model()
ADMIN_HOST = "admin.archivebox.localhost:8000"


@pytest.fixture
def admin_user(db):
    return cast(UserManager, User.objects).create_superuser(
        username="rssadmin",
        email="rssadmin@test.com",
        password="testpassword",
    )


@pytest.fixture
def other_user(db):
    return cast(UserManager, User.objects).create_user(
        username="rssother",
        email="rssother@test.com",
        password="testpassword",
    )


@pytest.fixture
def api_token(admin_user):
    from archivebox.api.auth import get_or_create_api_token

    token = get_or_create_api_token(admin_user)
    assert token is not None
    return token.token


def make_snapshot(*, user, url: str, title: str, bookmarked_at: datetime):
    from archivebox.core.models import Snapshot
    from archivebox.crawls.models import Crawl

    crawl = Crawl.objects.create(urls=url, created_by=user)
    snapshot = Snapshot.objects.create(
        url=url,
        title=title,
        crawl=crawl,
        bookmarked_at=bookmarked_at,
    )
    return crawl, snapshot


def test_snapshots_rss_filters_by_user_and_orders_newest_first(client, api_token, admin_user, other_user):
    from archivebox.core.models import Tag

    older_at = timezone.make_aware(datetime(2026, 5, 22, 8, 0, 0))
    newer_at = timezone.make_aware(datetime(2026, 5, 23, 8, 0, 0))
    _crawl, older_snapshot = make_snapshot(
        user=admin_user,
        url="https://example.com/rss-older",
        title="Older & Escaped",
        bookmarked_at=older_at,
    )
    make_snapshot(
        user=admin_user,
        url="https://example.com/rss-newer",
        title="Newer Snapshot",
        bookmarked_at=newer_at,
    )
    make_snapshot(
        user=other_user,
        url="https://example.com/rss-other-user",
        title="Other User",
        bookmarked_at=timezone.make_aware(datetime(2026, 5, 23, 9, 0, 0)),
    )
    older_snapshot.tags.add(Tag.objects.create(name="rss-tag", created_by=admin_user))

    response = client.get(
        "/api/v1/core/snapshots.rss",
        {"created_by": admin_user.username, "limit": 50, "api_key": api_token},
        HTTP_HOST=ADMIN_HOST,
    )

    assert response.status_code == 200
    assert response["Content-Type"].startswith("application/rss+xml")
    body = response.content.decode()
    assert '<rss version="2.0"' in body
    assert api_token not in body
    assert 'href="http://admin.archivebox.localhost:8000/api/v1/core/snapshots.rss?created_by=rssadmin&amp;limit=50"' in body
    assert "Newer Snapshot" in body
    assert "Older &amp; Escaped" in body
    assert "Tags: rss-tag" not in body
    assert "<category>rss-tag</category>" in body
    assert "rss-other-user" not in body
    assert body.index("rss-newer") < body.index("rss-older")


def test_snapshots_rss_supports_before_yyyymmdd_and_limit(client, api_token, admin_user):
    make_snapshot(
        user=admin_user,
        url="https://example.com/rss-before-too-new",
        title="Too New",
        bookmarked_at=timezone.make_aware(datetime(2026, 5, 24, 8, 0, 0)),
    )
    make_snapshot(
        user=admin_user,
        url="https://example.com/rss-before-keep-one",
        title="Keep One",
        bookmarked_at=timezone.make_aware(datetime(2026, 5, 23, 12, 0, 0)),
    )
    make_snapshot(
        user=admin_user,
        url="https://example.com/rss-before-keep-two",
        title="Keep Two",
        bookmarked_at=timezone.make_aware(datetime(2026, 5, 22, 12, 0, 0)),
    )

    response = client.get(
        "/api/v1/core/snapshots.rss",
        {"created_by": str(admin_user.pk), "before": "20260523", "limit": 1, "api_key": api_token},
        HTTP_HOST=ADMIN_HOST,
    )

    assert response.status_code == 200
    body = response.content.decode()
    assert "rss-before-too-new" not in body
    assert "rss-before-keep-one" in body
    assert "rss-before-keep-two" not in body


def test_crawl_as_rss_redirects_to_canonical_snapshots_feed(client, api_token, admin_user, other_user):
    crawl, _snapshot = make_snapshot(
        user=admin_user,
        url="https://example.com/rss-crawl-feed",
        title="Crawl Feed Snapshot",
        bookmarked_at=timezone.make_aware(datetime(2026, 5, 23, 8, 0, 0)),
    )
    make_snapshot(
        user=other_user,
        url="https://example.com/rss-crawl-other",
        title="Other Crawl Snapshot",
        bookmarked_at=timezone.make_aware(datetime(2026, 5, 23, 9, 0, 0)),
    )

    response = client.get(
        f"/api/v1/crawls/crawl/{crawl.id}",
        {"as_rss": "true", "limit": 50, "api_key": api_token},
        HTTP_HOST=ADMIN_HOST,
        follow=True,
    )

    assert response.status_code == 200
    assert response.redirect_chain
    redirect_url = response.redirect_chain[0][0]
    assert redirect_url.startswith("/api/v1/core/snapshots.rss?")
    assert f"crawl_id={crawl.id}" in redirect_url
    assert "as_rss" not in redirect_url
    assert response["Content-Type"].startswith("application/rss+xml")
    body = response.content.decode()
    assert "rss-crawl-feed" in body
    assert "rss-crawl-other" not in body
