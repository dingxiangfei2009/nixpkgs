# This file was generated by https://github.com/kamilchm/go2nix v1.2.1
{ stdenv, buildGoPackage, fetchgit, fetchhg, fetchbzr, fetchsvn }:

buildGoPackage rec {
  name = "grootfs-unstable-${version}";
  version = "2018-07-10";
  rev = "600df5a80cf64b7f85abd5930e772e602df6be41";

  goPackagePath = "code.cloudfoundry.org/grootfs";

  src = fetchgit {
    inherit rev;
    url = "https://github.com/cloudfoundry/grootfs";
    sha256 = "1jixzhz85qj7whwa66bx1qm1nzs8shddbqa58ss8hdgkfa53hljk";
  };

  goDeps = ./deps.nix;

  # TODO: add metadata https://nixos.org/nixpkgs/manual/#sec-standard-meta-attributes
  meta = {
    platforms = stdenv.lib.platforms.linux;
  };
}
