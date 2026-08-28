"""Task 3 fixture: an async cache with a race condition.

Symptom (see stacktrace.txt): under concurrent load, `fetch_profile` raises
KeyError from `_inflight.pop(user_id)` and callers intermittently receive
None instead of a profile. Diagnose from the stack trace and fix.
"""

import asyncio

_cache: dict[str, dict] = {}
_inflight: dict[str, asyncio.Future] = {}


async def _load_from_db(user_id: str) -> dict:
    await asyncio.sleep(0.05)  # simulated I/O
    return {"id": user_id, "name": f"user-{user_id}"}


async def fetch_profile(user_id: str) -> dict:
    if user_id in _cache:
        return _cache[user_id]
    if user_id in _inflight:
        return await _inflight[user_id]
    future = asyncio.get_event_loop().create_future()
    _inflight[user_id] = future
    profile = await _load_from_db(user_id)
    _cache[user_id] = profile
    future.set_result(profile)
    _inflight.pop(user_id)
    return profile


async def warm(user_ids: list[str]) -> None:
    # Also clears stale entries while warming -- runs concurrently with reads.
    for uid in user_ids:
        _cache.pop(uid, None)
        _inflight.pop(uid, None)
    await asyncio.gather(*(fetch_profile(u) for u in user_ids))


async def main() -> None:
    ids = [str(i % 5) for i in range(200)]
    await asyncio.gather(*(fetch_profile(u) for u in ids), warm(["1", "2", "3"]))


if __name__ == "__main__":
    asyncio.run(main())
