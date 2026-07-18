# Linux 7.1.1 NSPA porting evidence

## Inputs

| Input | URL or repository path | SHA-256 |
| --- | --- | --- |
| Linux source | `https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.1.1.tar.xz` | `sha256-UhX6NUHcfn9bzVG/flfxac7G/OUIylTj3IX97hQ3HX0=` |
| PREEMPT_RT | `https://cdn.kernel.org/pub/linux/kernel/projects/rt/7.1/patch-7.1.1-rt2.patch.xz` | `sha256-pb0ELCQ6Ml+mu8wlOExv0ulXC726EjW5Lf2d5QvJkJA=` |
| NSPA patch source | `linux-nspa/` from locked `github:nine7nine/Linux-NSPA-pkgbuild` revision `eccca594aa733be4c6c2f68314e86628a9f07c55` | `sha256-FTF6sH1ggwemHt1lN0oZkec+q3RYP8JmCLBs+aPateY=` |

## Per-patch review

| Ordered patch | Apply result | Semantic review against Linux 7.1.1 + RT | Resolution |
| --- | --- | --- | --- |
| `1001-ntsync-preempt-rt-lock-hardening.patch` | Clean `-p1 --dry-run`, then applied after RT; no offset, fuzz, or reject. | `dev_lock_obj`, `dev_unlock_obj`, `obj_lock`, `obj_unlock`, wait setup/unqueue, and device init: object state/list locks are `raw_spinlock_t`; wait-all serialization is `rt_mutex`. `dev_locked` remains read/written under the object lock and wait-all still has a sleepable lock. | No rebase; 7.1.1 RT base preserves all lock sites. |
| `1002-ntsync-priority-ordered-waiter-queues.patch` | Clean `-p1 --dry-run`, then applied; no offset, fuzz, or reject. | `ntsync_insert_waiter` and both wait-any enqueue paths: list insertion remains inside `ntsync_lock_obj` or `dev_lock_obj`; ordering is priority ascending (`task->prio`) with FIFO ties. | No rebase; object-list locking is unchanged. |
| `1003-ntsync-mutex-owner-pi-boost.patch` | Clean `-p1 --dry-run`, then applied; no offset, fuzz, or reject. | `ntsync_pi_recalc`, `ntsync_pi_drop`, `ntsync_pi_set_owner`, mutex wake/unlock/kill/free and wait queue/unqueue paths: owner references are acquired before publication and released on transfer/free; `boosted_owners` and counts are serialized by `boost_lock`; object or wait-all ownership is asserted before waiter scans. | No rebase; later 1004 hoists PI-owner allocation/free out of raw locks. |
| `1004-ntsync-channel-thread-token-alloc-hoist.patch` | Clean `-p1 --dry-run`, then applied; no offset, fuzz, or reject. | Channel create/send/recv/reply/register lifecycle plus PI-work helpers: channel trees, depth, dispatched list, and thread registry remain under `obj_lock`; all GFP_KERNEL allocation/free is moved before or after raw-lock regions, and PI work is finished after unlock. | No rebase; combined 1004-1006 applies as its locked source requires. |
| `1007-ntsync-shared-boost-channel-recv-fixes.patch` | Clean `-p1 --dry-run`, then applied; no offset, fuzz, or reject. | Event PI staging/consumption, event reset/free, wait unqueue, and channel recv/recv2: staged event PI is taken and cleared under object locking, then applied/freed after unlock; exclusive receiver waits make the selected receiver the wake winner; entry lifetime is deferred by its refcount. | No rebase; all changed sites target the RT-hardened locking model. |
| `1009-ntsync-channel-entry-refcount.patch` | Clean `-p1 --dry-run`, then applied; no offset, fuzz, or reject. | Channel send cleanup and reply: REPLY increments the entry refcount under `obj_lock` before dropping it, wakes outside the raw object lock, and both REPLY and sender free only on the final decrement. | No rebase; preserves the required no-waitqueue-lock-under-raw-lock invariant. |
| `1010-ntsync-aggregate-wait.patch` | Clean `-p1 --dry-run`, then applied; no offset, fuzz, or reject. | Channel signaled/notify/send paths and aggregate setup/wait/unqueue: channel state and object waiters remain under `obj_lock`; PI target lookup precedes wake; poll registrations and all dynamic allocation/free occur outside raw locks; mutex PI work is completed after unqueue. | No rebase; 7.1.1 RT base accepts the added UAPI and driver paths unchanged. |
| `1011-ntsync-channel-try-recv2.patch` | Clean `-p1 --dry-run`, then applied; no offset, fuzz, or reject. | `ntsync_channel_recv2` and ioctl dispatch: nonblocking empty-queue exit occurs after releasing `obj_lock`; blocking behavior continues to use the existing exclusive wait queue. | No rebase; no new locking or allocation path. |
| `1012-ntsync-channel-recv-snapshot-pop-fields-uaf-fix.patch` | Clean `-p1 --dry-run`, then applied; no offset, fuzz, or reject. | `ntsync_channel_recv` and `ntsync_channel_recv2`: entry fields and PI parameters are copied while `obj_lock` is held; boost remains outside the raw lock and no entry pointer is dereferenced after unlock. | No rebase; closes the sender-cleanup versus receiver UAF window. |
| `1013-ntsync-dedicated-slab-caches.patch` | Clean `-p1 --dry-run`, then applied; no offset, fuzz, or reject. | Module init/exit and event-PI, channel-entry, and PI-owner allocation/free sites: dedicated cache lifetime follows registration/unwind ordering; raw-locked paths only manipulate preallocated/listed objects, with cache allocation/free outside raw locks. | No rebase; preserves the 1006 allocation-hoist invariant. |
| `1014-ntsync-channel-send-pi-lockless-target-scan.patch` | Clean `-p1 --dry-run`, then applied; no offset, fuzz, or reject. | Channel SEND_PI receiver-target lookup: `list_empty_careful` is a best-effort acquire-ordered empty fast path; a nonempty list is still walked under `recv_wq.lock`, with task reference acquisition before unlock. | No rebase; only the empty fast path omits a lock and fallback behavior is retained. |
| `1015-ntsync-wait-q-kmem-cache.patch` | Clean `-p1 --dry-run`, then applied; no offset, fuzz, or reject. | Wait queue allocation/free helpers, wait-any/all, aggregate wait, and module init/exit: cache-vs-kmalloc routing is recorded per queue; allocation happens before locks and freeing after unqueue/PI-work completion; cache creation/destruction has mirrored unwind. | No rebase; preserves 1006's no-sleeping-allocation-under-raw-lock invariant. |

## Application evidence

- Both fetched files were prefetched with the hashes above.
- `nix flake metadata --json .` identified the locked NSPA revision and nar hash above.
- In `/tmp/opencode/linux-nspa-7.1.1-port`, the RT patch dry run was clean and was applied before the NSPA series.
- Each listed NSPA patch dry run was clean and was then applied in the stated order. No patch required a semantic rebase.

## Build evidence

- `nix build .#checks.x86_64-linux.linux-nspa-kernel --no-link --print-out-paths` exited zero on 2026-07-19 and returned `/nix/store/7s0z3gx3fw3xyj1hp4l1ibbvjmifvriy-linux-7.1.1`.
- `nix-store --query --outputs` for the fixed kernel derivation returned the kernel output above, `/nix/store/k5ih4ga6f1yhlyg74d2gbp7m50m8cxys-linux-7.1.1-dev`, and `/nix/store/94irl21ybazfsl2107api283yqjh3l8z-linux-7.1.1-modules`.

## Normalized configuration validation

The pre-fix effective configuration had `CONFIG_NTSYNC=y` and
`CONFIG_HIGH_RES_TIMERS=y`, but `CONFIG_PREEMPT_RT` was unset. The root cause
was not Kconfig normalization: `pkgs.buildLinux` does not use this expression's
`configfile` argument. It generates the build configuration from its defaults
and `extraConfig`; before this correction, `extraConfig` selected only NTSYNC.
The source `linux-nspa/config` setting for PREEMPT_RT therefore never reached
the built configuration.

`flake.nix` now explicitly sets both `NTSYNC y` and `PREEMPT_RT y` in
`extraConfig`. The fixed flake exposes
`checks.x86_64-linux.linux-nspa-config`, which reads the installed build
configuration at `$kernel.dev/lib/modules/$kernel.modDirVersion/build/.config`
and asserts the RT, timer, tickless, and NSPA-critical baseline below.

This check failed against the pre-fix configuration because PREEMPT_RT was
unset. Post-fix evidence, recorded on 2026-07-19, is:

```sh
nix build .#checks.x86_64-linux.linux-nspa-config --no-link --print-out-paths
# /nix/store/kl8rdajzdi59l99z1d5air1gnvs971k6-linux-nspa-config

nix build .#checks.x86_64-linux.linux-nspa-kernel --no-link --print-out-paths
# /nix/store/7s0z3gx3fw3xyj1hp4l1ibbvjmifvriy-linux-7.1.1
```

Both commands exited zero; the kernel output was cached while the strengthened
configuration check was rebuilt. The material comparison of
`linux-nspa/config` and the installed fixed configuration at
`/nix/store/k5ih4ga6f1yhlyg74d2gbp7m50m8cxys-linux-7.1.1-dev/lib/modules/7.1.1-rt2/build/.config`
is:

| Setting | `linux-nspa/config` | Fixed built `.config` | Assessment |
| --- | --- | --- | --- |
| `CONFIG_PREEMPT_RT` | `y` | `y` | Preserved; explicitly selected by `extraConfig`. |
| `CONFIG_NTSYNC` | `y` | `y` | Preserved. |
| `CONFIG_HIGH_RES_TIMERS` | `y` | `y` | Preserved. |
| `CONFIG_HZ_1000`, `CONFIG_HZ` | `y`, `1000` | `y`, `1000` | Preserved 1000 Hz timer frequency. |
| `CONFIG_NO_HZ`, `CONFIG_NO_HZ_FULL`, `CONFIG_NO_HZ_IDLE` | `y`, `y`, unset | `y`, `y`, unset | Preserved full-dynticks mode; idle-only tickless mode remains disabled. |
| `CONFIG_IRQ_FORCED_THREADING` | `y` | `y` | Preserved. |
| `CONFIG_CPU_ISOLATION` | `y` | `y` | Preserved. |
| `CONFIG_RCU_NOCB_CPU` | `y` | `y` | Preserved. |
| `CONFIG_RCU_NOCB_CPU_CB_BOOST` | `y` | `y` | Preserved; it is emitted by the fixed config. |
| `CONFIG_RT_MUTEXES` | `y` | `y` | Preserved. |
| `CONFIG_RT_GROUP_SCHED` | unset | unset | Preserved. |
| `CONFIG_PREEMPT_LAZY` | `y` | `y` | Preserved. |
| `CONFIG_DEBUG_PREEMPT` | `y` | unset | Kconfig normalization disables debug preemption in the fixed build; this is the only material difference in this comparison and is asserted as unset. |

No listed material symbol is absent from the fixed configuration. In
particular, the earlier pre-fix report that `CONFIG_RCU_NOCB_CPU_CB_BOOST` was
not emitted is superseded by the fixed build evidence above. No downstream
configuration was changed.

## Built output metadata

- The fixed modules output is `/nix/store/94irl21ybazfsl2107api283yqjh3l8z-linux-7.1.1-modules` and contains `lib/modules/7.1.1-rt2/`; therefore the actual `modDirVersion` is `7.1.1-rt2`.
- `nix eval --raw .#legacyPackages.x86_64-linux.linux-nspaPackages.kernel.version` returned `7.1.1`.
