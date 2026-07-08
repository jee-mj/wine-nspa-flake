{
  description = "Wine-NSPA 11.8 + Linux-NSPA 7.0.12 — inputs for .site Ableton lab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    wine-nspa-src = {
      url = "github:nine7nine/wine-nspa-src";
      flake = false;
    };
    linux-nspa-kernel = {
      url = "github:nine7nine/Linux-NSPA-pkgbuild";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, wine-nspa-src, linux-nspa-kernel }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      # Wine-NSPA identifies as Wine 11.8.  Use nixpkgs' development Wine
      # package as the build template rather than stableFull (11.0), so the
      # generated build inputs, patches, and configure surface stay close to
      # the upstream Wine generation NSPA rebased onto.  Avoid stagingFull here:
      # Wine-NSPA is already a forked source tree and mixing Wine-Staging's
      # source-family assumptions into it adds another patch stack without a
      # demonstrated runtime benefit.
      wine-nspa = pkgs.wineWow64Packages.unstableFull.overrideAttrs (prev: rec {
        pname = "wine-nspa";
        version = "11.8";
        src = wine-nspa-src;

        patches = builtins.filter
          (p: ! (builtins.match ".*add-dll-accept-device-paths.*" (builtins.unsafeDiscardStringContext (toString p)) != null))
          (prev.patches or [ ]);

        buildInputs = (prev.buildInputs or [ ]) ++ [
          pkgs.libjack2
          pkgs.liburing
        ];

        configureFlags = (prev.configureFlags or [ ]) ++ [
          "--enable-nspa-arch=v3"
          "--with-uring"
        ];

        meta = (prev.meta or { }) // {
          description = "Wine-NSPA 11.8 — PREEMPT_RT Wine fork (decoration-loop fix + PI)";
          homepage = "https://github.com/nine7nine/Wine-NSPA";
          platforms = [ "x86_64-linux" ];
        };
      });

      linux-nspaPackages = pkgs.linuxPackagesFor (pkgs.buildLinux {
        version = "7.0.12";
        modDirVersion = "7.0.12-rt2";

        src = pkgs.fetchurl {
          url = "https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.0.12.tar.xz";
          hash = "sha256-V+3JpB78HKa3l6+o9KWHow2ir2vKc1brVuHhpK2iZdo=";
        };

        kernelPatches = map (name: {
          name = builtins.baseNameOf name;
          patch = "${linux-nspa-kernel}/linux-nspa/${name}";
        }) [
          "0000-patch-7.0.1-rt2.patch"
          "1001-ntsync-preempt-rt-lock-hardening.patch"
          "1002-ntsync-priority-ordered-waiter-queues.patch"
          "1003-ntsync-mutex-owner-pi-boost.patch"
          "1004-ntsync-channel-thread-token-alloc-hoist.patch"
          "1007-ntsync-shared-boost-channel-recv-fixes.patch"
          "1009-ntsync-channel-entry-refcount.patch"
          "1010-ntsync-aggregate-wait.patch"
          "1011-ntsync-channel-try-recv2.patch"
          "1012-ntsync-channel-recv-snapshot-pop-fields-uaf-fix.patch"
          "1013-ntsync-dedicated-slab-caches.patch"
          "1014-ntsync-channel-send-pi-lockless-target-scan.patch"
          "1015-ntsync-wait-q-kmem-cache.patch"
        ];

        configfile = "${linux-nspa-kernel}/linux-nspa/config";

        extraConfig = ''
          NTSYNC y
        '';

        meta = {
          description = "Linux-NSPA 7.0.12 — PREEMPT_RT kernel with ntsync PI for Wine-NSPA";
          homepage = "https://github.com/nine7nine/Linux-NSPA-pkgbuild";
          platforms = [ "x86_64-linux" ];
        };
      });

      linux-nspa = linux-nspaPackages.kernel;
    in
    {
      packages.${system} = {
        inherit wine-nspa linux-nspa;
      };

      legacyPackages.${system} = {
        inherit linux-nspaPackages;
      };

      overlays.default = final: prev: {
        wine-nspa = self.packages.${final.stdenv.hostPlatform.system}.wine-nspa;
        linux-nspa = self.packages.${final.stdenv.hostPlatform.system}.linux-nspa;
        linuxPackages_nspa = self.legacyPackages.${final.stdenv.hostPlatform.system}.linux-nspaPackages;
      };

      checks.${system} = {
        inherit wine-nspa linux-nspa;
      };
    };
}
