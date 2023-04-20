{
  description = "NixOS images";

  inputs = {
    nixos-unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    nixos-2211.url = "github:NixOS/nixpkgs/release-22.11";
    flake-parts = { url = "github:hercules-ci/flake-parts"; inputs.nixpkgs-lib.follows = "nixos-unstable"; };
    hercules-ci-effects = { url = "github:Kranzes/hercules-ci-effects/submodule-gh-release"; inputs.nixpkgs.follows = "nixos-unstable"; };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } ({ config, ... }: {
      systems = [ "x86_64-linux" ]; # "aarch64-linux" ];
      imports = [ inputs.hercules-ci-effects.flakeModule ];

      flake.nixosModules.kexec-installer = import ./nix/kexec-installer/module.nix;

      perSystem = { inputs', system, pkgs, pkgs2211, ... }: {
        _module.args = {
          pkgs = inputs'.nixos-unstable.legacyPackages;
          pkgs2211 = inputs'.nixos-2211.legacyPackages;
        };

        packages =
          let
            netboot = nixpkgs: (import (nixpkgs + "/nixos/release.nix") { }).netboot.${system};
            kexec-installer = pkgs: (pkgs.nixos [ inputs.self.nixosModules.kexec-installer ]).config.system.build.kexecTarball;
          in
          {
            netboot-nixos-unstable = netboot inputs.nixos-unstable;
            #  netboot-nixos-2211 = netboot inputs.nixos-2211;
            kexec-installer-nixos-unstable = kexec-installer pkgs;
            #  kexec-installer-nixos-2211 = kexec-installer pkgs2211;
          };

        #checks = {
        #  kexec-installer-unstable = pkgs.callPackage ./nix/kexec-installer/test.nix { };
        #  shellcheck = pkgs.runCommand "shellcheck" { } "${pkgs.lib.getExe pkgs.shellcheck} ${(pkgs.nixos [inputs.self.nixosModules.kexec-installer]).config.system.build.kexecRun} && touch $out";
        #};
        devShells.default = pkgs.mkShell { packages = [ pkgs.hci ]; };
      };

      hercules-ci = {
        flake-update = {
          enable = true;
          updateBranch = "main";
          createPullRequest = true;
          autoMergeMethod = "merge";
          # Update  everynight at midnight
          when = {
            hour = [ 0 ];
            minute = 0;
          };
        };

        github-releases = {
          systems = config.systems;
          releaseTag = _: builtins.concatStringsSep "-" (builtins.match "(.{4})(.{2})(.{2}).*" inputs.self.lastModifiedDate);
          condition = { branch, ... }: (branch == "main");
          updatePrev = _: true;
          filesPerSystem = { pkgs, self', system, ... }: [
            {
              label = "nixos-kexec-installer-${system}.tar.gz";
              path = "${self'.packages.kexec-installer-nixos-unstable}/nixos-kexec-installer-${system}.tar.gz";
            }
            {
              label = "bzImage-${system}";
              path = "${self'.packages.netboot-nixos-unstable}/bzImage";
            }
            {
              label = "initrd-${system}";
              path = "${self'.packages.netboot-nixos-unstable}/initrd";
            }
            {
              label = "netboot-${system}.ipxe";
              path = "${self'.packages.netboot-nixos-unstable}/netboot.ipxe";
            }
            #{
            #  label = "sha256sums-${system}";
            #  path = pkgs.runCommand "sha256sums-${system}" { } ''
            #    ${pkgs.lib.concatMapStringsSep "\n" ({ label, path }: if label == "sha256sums-${system}" then "true" else
            #      "ln -s ${path} ${label} && export files+=(${label})") config.hercules-ci.github-releases.finalFiles}
            #    sha256sum $files > "$out"
            #  '';
            #}
          ];
        };
      };
    });
}
