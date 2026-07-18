# Wine-NSPA implementational debt analysis

## Current status

- Wine-NSPA 11.8 builds successfully and reports `wine-11.8 (NSPA)`.
- Linux-NSPA 7.0.12 builds successfully with module directory version `7.0.12-rt2`.
- This flake exports both the Linux-NSPA kernel derivation and the full `linuxPackagesFor` package set for NixOS consumers.
- Runtime validation is intentionally deferred to a host rebuild, boot, restart, and manual Ableton test.

> Generated from deep inspection of the `wine-nspa-src`, `Linux-NSPA-pkgbuild`,
> and `librtpi` repositories.

## Architecture map

```
┌─────────────────────────────────────────────────────────┐
│ .site                                                   │
│   winePackage = wine-nspa   (in hosts/hostname/)       │
│   kernel     = linux-nspa   (optional, boot.kernelPackages) │
└────────────┬────────────────────────────────────────────┘
             │ consumes
┌────────────▼────────────────────────────────────────────┐
│ wine-nspa-flake  (wine-nspa-flake)         │
│   packages.wine-nspa   ← overrideAttrs on stableFull    │
│   packages.linux-nspa  ← buildLinux + ntsync patches    │
└────────────┬────────────────────────────────────────────┘
             │ builds from
┌────────────▼────────────────────────────────────────────┐
│ wine-nspa-src       (github:nine7nine/wine-nspa-src)    │
│   Wine 11.8 + ~400 NSPA commits on top                  │
│   Self-contained: bundles header-only librtpi in-tree   │
│   Standard autotools build (same as stock Wine)         │
│   Key add: --enable-nspa-arch=v3|v4-narrow|v4          │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ linux-nspa-kernel   (github:nine7nine/Linux-NSPA-pkgbuild) │
│   Linux 7.0.12 + PREEMPT_RT + ~30 patches               │
│   12 of those are ntsync PI patches (1001-1015)         │
│   Arch PKGBUILD → Nix: use buildLinux + configfile       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ librtpi             (github:nine7nine/librtpi)          │
│   NOT NEEDED as external dep                            │
│   Wine-NSPA bundles a header-only reimplementation at   │
│   libs/librtpi/rtpi.h — see include/rtpi.h              │
└─────────────────────────────────────────────────────────┘
```

## What we gain

| Feature | Stock Wine 11.0 | Wine-NSPA 11.8 |
|---------|:---:|:---:|
| Decoration loop fix (jitter) | ❌ Bug #57955 | ✅ Fixed |
| Client-side NT surfaces | ❌ | ✅ Local files/sections bypass wineserver |
| Gamma channel dispatcher | ❌ | ✅ Kernel-mediated IPC, lower overhead |
| Priority inheritance | ❌ | ✅ pi_mutex/pi_cond replace pthread |
| Hot-path optimizations | baseline | ✅ msg-ring, paint-cache, AVX2 loops |
| RT memory | ❌ | ✅ mlockall, hugetlb promotion |
| nspaASIO/winejack drivers | ❌ | ✅ Additional audio backends |
| ntsync PI (kernel side) | ❌ | ✅ With Linux-NSPA kernel |

## Implementation debt — line items

### 1. Nix derivation for wine-nspa  `wine-nspa-flake/`

**Status:** Flake verified.  Both derivations build successfully from GitHub sources.  Uses `overrideAttrs` on `wineWow64Packages.stableFull` to swap source and add `--enable-nspa-arch=v3`.

**Risk: Medium.**  The `overrideAttrs` approach relies on nixpkgs' internal wine build structure not changing incompatibly between the pinned nixpkgs revision and the version used at build time.  If the wine packaging changes in nixpkgs, the override may need updating.

**Mitigation:** Pin nixpkgs in the flake input to match .site's nixpkgs.  Currently using `nixos-unstable`; change to match .site's `flake.lock` revision.

**Build time:** Stock Wine builds take 20-40 minutes on this workstation (12-core 7600X).  Wine-NSPA adds no new dependencies — the header-only librtpi is in-tree — so build time should be comparable.

### 2. Nix derivation for linux-nspa  `wine-nspa-flake/kernel/`

**Status:** Flake verified.  Uses `buildLinux` from nixpkgs with the NSPA kernel source + config + patches.  **Config is for Surface 7 — needs HOSTNAME localmodconfig.**

**Risk: High.**  Custom kernels are always risky:
- 7.0.12 may not have all the hardware drivers HOSTNAME needs
- PREEMPT_RT can expose driver bugs (the config includes workaround patches)
- Kernel config is 11k lines tuned for a Surface 7 — must generate a HOSTNAME config
- Out-of-tree modules (NVIDIA, ZFS?) must be rebuilt against this kernel
- Each kernel update requires a full rebuild (30-60 min)

**Mitigation:** Wine-NSPA works with the stock kernel.  The ntsync PI kernel features are a performance optimization, not a hard requirement.  Start without the kernel switch; add it only if RT performance is insufficient.

### 3. NixOS integration

**Status:** Not done.  Requires:
1. Add `inputs.wine-nspa.url = "github:jee-mj/wine-nspa-flake";` to `.site/flake.nix`
2. Change `winePackage = pkgs.wineWow64Packages.stableFull;` to `winePackage = inputs.wine-nspa.packages.x86_64-linux.wine-nspa;`
3. Rebuild and test

### 4. WineASIO compatibility

**Status:** Unknown.  Wine-NSPA adds `nspaASIO` and `winejack` drivers but does not remove stock WineASIO support.  The `pkgs.wineasio` package in nixpkgs is built against a specific Wine version — if the Wine ABI changed between 11.0 and 11.8, wineasio may need rebuilding.

**Risk: Medium.**  If wineasio breaks:
- Fall back to nspaASIO (built-in, no separate package)
- Or rebuild wineasio against wine-nspa

### 5. yabridge compatibility

**Status:** Unknown.  The Wine-NSPA project maintains its own `Yabridge-NSPA` fork.  Stock yabridge may or may not work with wine-nspa.  The NSPA issue #15 mentions "Ableton Live && Yabridge are kind of borked" in the Wine-10.x rebase.

**Risk: High.**  If stock yabridge breaks:
- Use Yabridge-NSPA (another package to maintain)
- Or test and fix as needed

### 6. Single maintainer risk

The entire NSPA ecosystem (wine-nspa-src, Linux-NSPA-kernel, librtpi, Yabridge-NSPA) is maintained by one person.  The repo carries a "WARNING: Forced Pushes && Resets" banner.  If the maintainer stops working on this, we either:
- Freeze at the last working commit (short-term ok, long-term stale)
- Maintain our own fork (400+ commits of Wine internals — massive burden)
- Return to stock Wine and re-apply just the decoration-loop fix as a patch

### 7. Test coverage
Wine-NSPA has an RT test suite (`nspa/tests/`) but no UI/application-level tests.  Ableton-specific testing is manual.  The decoration-loop fix is "X11 fixed, Wayland untested" per the investigation document.  We're on KDE Wayland.

## Recommended adoption path

```
Phase 1: Wine-NSPA only, stock kernel
  ├── Build wine-nspa via flake  (this directory)
  ├── Point .site at it
  ├── Verify: Ableton no longer jitters on Wayland
  ├── Verify: wineasio still works (or switch to nspaASIO)
  ├── Verify: yabridge still works (or evaluate Yabridge-NSPA)
  └── Decision gate: does the decoration-loop fix hold on Wayland?

Phase 2: Kernel switch (only if RT perf insufficient)
  ├── Generate HOSTNAME localmodconfig from NSPA baseline
  ├── Build linux-nspa
  ├── Verify: NVIDIA driver builds against it
  ├── Verify: all hardware works (audio, network, USB, GPU)
  └── Switch boot.kernelPackages

Phase 3: Long-term maintenance plan
  ├── Pin wine-nspa-src to a specific commit (not a branch)
  ├── Track upstream for rebases
  └── OR: extract just the decoration-loop fix as a standalone
         Nixpkgs overlay patch (2-3 files in win32u/) and drop
         the full fork
```

## Files in this directory

```text
wine-nspa-flake/
├── flake.nix     # Builds and exports Wine-NSPA and Linux-NSPA packages
├── flake.lock    # Pins inputs after first lock update
├── .gitignore    # Ignores local result symlinks
└── README.md     # Integration notes and risk register
```

wine-nspa-src/         # Cloned wine-nspa source (Wine 11.8 + patches)
linux-nspa-kernel/     # Cloned kernel PKGBUILD + patches + config
librtpi/               # Cloned librtpi (not needed externally)
```

## Quick start

```fish
# Build wine-nspa (will take 20-40 min first time)
cd wine-nspa-flake
nix build .#wine-nspa --no-link --print-out-paths

# Verify the wine binary
result/bin/wine --version   # should print "wine-11.8" (NSPA)

# Test in Ableton prefix
WINEPREFIX=/path/to/wine/prefix result/bin/wine --version
```

## Linux-NSPA kernel baseline

The NSPA kernel is based on Linux 7.1.1 with the exact upstream
`7.1.1-rt2` PREEMPT_RT patch. The accompanying NSPA patch series is reviewed
as a semantic port from Linux 7.0.12. Build the reproducible kernel gate with:

```sh
nix build .#checks.x86_64-linux.linux-nspa-kernel --no-link
```
