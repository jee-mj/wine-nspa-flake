# Linux 7.1.1 NSPA porting evidence

## Inputs

| Input | URL or repository path | SHA-256 |
| --- | --- | --- |
| Linux source | `https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.1.1.tar.xz` | |
| PREEMPT_RT | `https://cdn.kernel.org/pub/linux/kernel/projects/rt/7.1/patch-7.1.1-rt2.patch.xz` | |
| NSPA patch source | `linux-nspa/` from the locked `linux-nspa-kernel` input | |

## Per-patch review

| Ordered patch | Apply result | Semantic review against Linux 7.1.1 + RT | Resolution |
| --- | --- | --- | --- |
| `1001-ntsync-preempt-rt-lock-hardening.patch` | | | |
| `1002-ntsync-priority-ordered-waiter-queues.patch` | | | |
| `1003-ntsync-mutex-owner-pi-boost.patch` | | | |
| `1004-ntsync-channel-thread-token-alloc-hoist.patch` | | | |
| `1007-ntsync-shared-boost-channel-recv-fixes.patch` | | | |
| `1009-ntsync-channel-entry-refcount.patch` | | | |
| `1010-ntsync-aggregate-wait.patch` | | | |
| `1011-ntsync-channel-try-recv2.patch` | | | |
| `1012-ntsync-channel-recv-snapshot-pop-fields-uaf-fix.patch` | | | |
| `1013-ntsync-dedicated-slab-caches.patch` | | | |
| `1014-ntsync-channel-send-pi-lockless-target-scan.patch` | | | |
| `1015-ntsync-wait-q-kmem-cache.patch` | | | |
