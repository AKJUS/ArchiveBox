from archivebox.config import VERSION
from archivebox.config.version import get_COMMIT_HASH


def archivebox_globals(request):
    return {
        "VERSION": VERSION,
        "STATIC_CACHE_KEY": (get_COMMIT_HASH() or VERSION or "dev").strip(),
    }
