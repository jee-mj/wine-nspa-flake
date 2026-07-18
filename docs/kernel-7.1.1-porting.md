# Linux 7.1.1 NSPA porting evidence

## Inputs

| Input | URL or repository path | SHA-256 |
| --- | --- | --- |
| Linux source | `https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.1.1.tar.xz` | `sha256-UhX6NUHcfn9bzVG/flfxac7G/OUIylTj3IX97hQ3HX0=` |
| PREEMPT_RT | `https://cdn.kernel.org/pub/linux/kernel/projects/rt/7.1/patch-7.1.1-rt2.patch.xz` | `sha256-pb0ELCQ6Ml+mu8wlOExv0ulXC726EjW5Lf2d5QvJkJA=` |
| NSPA patch source | `linux-nspa/` from the locked `linux-nspa-kernel` input | |

## Per-patch review

| Ordered patch | Apply result | Semantic review against Linux 7.1.1 + RT | Resolution |
| --- | --- | --- | --- |
| `1001-ntsync-preempt-rt-lock-hardening.patch` | `pending-task-2` | `pending-task-2` | `Task 2 must replace all pending fields` |
| `1002-ntsync-priority-ordered-waiter-queues.patch` | `pending-task-2` | `pending-task-2` | `Task 2 must replace all pending fields` |
| `1003-ntsync-mutex-owner-pi-boost.patch` | `pending-task-2` | `pending-task-2` | `Task 2 must replace all pending fields` |
| `1004-ntsync-channel-thread-token-alloc-hoist.patch` | `pending-task-2` | `pending-task-2` | `Task 2 must replace all pending fields` |
| `1007-ntsync-shared-boost-channel-recv-fixes.patch` | `pending-task-2` | `pending-task-2` | `Task 2 must replace all pending fields` |
| `1009-ntsync-channel-entry-refcount.patch` | `pending-task-2` | `pending-task-2` | `Task 2 must replace all pending fields` |
| `1010-ntsync-aggregate-wait.patch` | `pending-task-2` | `pending-task-2` | `Task 2 must replace all pending fields` |
| `1011-ntsync-channel-try-recv2.patch` | `pending-task-2` | `pending-task-2` | `Task 2 must replace all pending fields` |
| `1012-ntsync-channel-recv-snapshot-pop-fields-uaf-fix.patch` | `pending-task-2` | `pending-task-2` | `Task 2 must replace all pending fields` |
| `1013-ntsync-dedicated-slab-caches.patch` | `pending-task-2` | `pending-task-2` | `Task 2 must replace all pending fields` |
| `1014-ntsync-channel-send-pi-lockless-target-scan.patch` | `pending-task-2` | `pending-task-2` | `Task 2 must replace all pending fields` |
| `1015-ntsync-wait-q-kmem-cache.patch` | `pending-task-2` | `pending-task-2` | `Task 2 must replace all pending fields` |
