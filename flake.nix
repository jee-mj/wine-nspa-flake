{
  description = "Wine-NSPA 11.8 + Linux-NSPA 7.1.1 — inputs for .site Ableton lab";

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

        patches = (builtins.filter
          (p: ! (builtins.match ".*add-dll-accept-device-paths.*" (builtins.unsafeDiscardStringContext (toString p)) != null))
          (prev.patches or [ ]))
          ++ [ ./patches/winejack-midi-caps-names.patch
               ./patches/wine-push3-usb-parentage.patch ];

        buildInputs = (prev.buildInputs or [ ]) ++ [
          pkgs.libjack2
          pkgs.liburing
        ];

        # Inherit configure flags from unstableFull but drop --with-wayland.
        # The experimental Wine Wayland driver causes popup-menu artifacts,
        # modal-dialog deadlocks, and plugin-loading freezes in FL Studio &
        # Ableton on Wayland hosts.  XWayland (the x11 driver) is battle-tested;
        # let it handle rendering while the Wayland driver matures.
        # See: github.com/nine7nine/Wine-NSPA/issues/4 (popup/blank menu bugs)
        configureFlags = builtins.filter
          (flag: flag != "--with-wayland")
          (prev.configureFlags or [ ])
          ++ [
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
        version = "7.1.1";
        modDirVersion = "7.1.1-rt2";

        src = pkgs.fetchurl {
          url = "https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.1.1.tar.xz";
          hash = "sha256-UhX6NUHcfn9bzVG/flfxac7G/OUIylTj3IX97hQ3HX0=";
        };

        kernelPatches = [
          {
            name = "patch-7.1.1-rt2.patch";
            patch = pkgs.fetchurl {
              url = "https://cdn.kernel.org/pub/linux/kernel/projects/rt/7.1/patch-7.1.1-rt2.patch.xz";
              hash = "sha256-pb0ELCQ6Ml+mu8wlOExv0ulXC726EjW5Lf2d5QvJkJA=";
            };
          }
        ] ++ map (name: {
          name = builtins.baseNameOf name;
          patch = "${linux-nspa-kernel}/linux-nspa/${name}";
        }) [
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
          PREEMPT_RT y
        '';

        meta = {
          description = "Linux-NSPA 7.1.1 — PREEMPT_RT kernel with ntsync PI for Wine-NSPA";
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
        linux-nspa-kernel = linux-nspaPackages.kernel;
        linux-nspa-config = pkgs.runCommand "linux-nspa-config" { } ''
          config=${linux-nspaPackages.kernel.dev}/lib/modules/${linux-nspaPackages.kernel.modDirVersion}/build/.config
          grep -qx 'CONFIG_PREEMPT_RT=y' "$config"
          grep -Eq '^CONFIG_NTSYNC=(y|m)$' "$config"
          grep -qx 'CONFIG_HIGH_RES_TIMERS=y' "$config"
          grep -qx 'CONFIG_HZ_1000=y' "$config"
          grep -qx 'CONFIG_HZ=1000' "$config"
          grep -qx 'CONFIG_NO_HZ=y' "$config"
          grep -qx 'CONFIG_NO_HZ_FULL=y' "$config"
          grep -qx '# CONFIG_NO_HZ_IDLE is not set' "$config"
          grep -qx 'CONFIG_IRQ_FORCED_THREADING=y' "$config"
          grep -qx 'CONFIG_CPU_ISOLATION=y' "$config"
          grep -qx 'CONFIG_RCU_NOCB_CPU=y' "$config"
          grep -qx 'CONFIG_RCU_NOCB_CPU_CB_BOOST=y' "$config"
          grep -qx 'CONFIG_RT_MUTEXES=y' "$config"
          grep -qx '# CONFIG_RT_GROUP_SCHED is not set' "$config"
          grep -qx 'CONFIG_PREEMPT_LAZY=y' "$config"
          grep -qx '# CONFIG_DEBUG_PREEMPT is not set' "$config"
          touch "$out"
        '';
      };
    };
}
