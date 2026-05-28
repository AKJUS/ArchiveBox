import pytest


pytestmark = pytest.mark.django_db


@pytest.mark.django_db(transaction=True)
def test_process_completed_persists_with_uncached_network_interface(tmp_path):
    import asyncio

    from abx_dl.events import CrawlCleanupEvent, ProcessCompletedEvent
    from abx_dl.orchestrator import create_bus
    from archivebox.machine.models import Machine, NetworkInterface, Process
    from archivebox.services.process_service import ProcessService

    machine = Machine.current()
    iface = NetworkInterface.current()

    output_dir = tmp_path / "headers"
    output_dir.mkdir()
    bus = create_bus(name="test_process_completed_uncached_iface")
    ProcessService(bus)

    async def run_event() -> None:
        event = bus.emit(
            ProcessCompletedEvent(
                plugin_name="headers",
                hook_name="on_Snapshot__27_headers.daemon.bg",
                hook_path="/bin/echo",
                hook_args=["--url=https://example.com"],
                is_background=True,
                output_dir=str(output_dir),
                env={},
                timeout=60,
                pid=123,
                stdout="",
                stderr="",
                exit_code=0,
                status="succeeded",
                output_files=[],
                start_ts="2026-05-13T07:22:00+00:00",
                end_ts="2026-05-13T07:22:01+00:00",
            ),
        )
        await event.now()
        await event.wait()
        await event.event_results_list()
        cleanup = bus.emit(
            CrawlCleanupEvent(
                url="https://example.com",
                snapshot_id="test-snapshot",
                output_dir=str(output_dir),
            ),
        )
        await cleanup.now()
        await cleanup.wait()

    asyncio.run(run_event())

    process = Process.objects.get(pwd=str(output_dir), cmd=["/bin/echo", "--url=https://example.com"])
    assert process.machine_id == machine.id
    assert process.iface_id == iface.id
    assert process.process_type == Process.TypeChoices.HOOK
    assert process.status == Process.StatusChoices.EXITED
