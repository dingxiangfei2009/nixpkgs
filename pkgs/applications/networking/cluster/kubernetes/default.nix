{ stdenv, buildPackages, lib, fetchFromGitHub, removeReferencesTo, which, go, go-bindata, makeWrapper, rsync
, components ? [
    "cmd/kubeadm"
    "cmd/kubectl"
    "cmd/kubelet"
    "cmd/kube-apiserver"
    "cmd/kube-controller-manager"
    "cmd/kube-proxy"
    "cmd/kube-scheduler"
    "test/e2e/e2e.test"
  ]
}:

with lib;

let
  cross-compilers = {
    "linux/amd64" = "arm-linux-gnueabihf-gcc";
    "linux/arm64" = "aarch64-linux-gnu-gcc";
    "linux/ppc64le" = "powerpc64le-linux-gnu-gcc";
    "linux/s390x" = "s390x-linux-gnu-gcc";
  };
  go-target = "${go.GOOS}/${go.GOARCH}";
in

stdenv.mkDerivation rec {
  name = "kubernetes-${version}";
  version = "1.14.3";

  src = fetchFromGitHub {
    owner = "kubernetes";
    repo = "kubernetes";
    rev = "v${version}";
    sha256 = "1r31ssf8bdbz8fdsprhkc34jqhz5rcs3ixlf0mbjcbq0xr7y651z";
  };

  nativeBuildInputs = [
    removeReferencesTo
    makeWrapper
    which
    rsync
    go
    go-bindata
    buildPackages.stdenv.cc
  ];

  inherit (go) GOOS GOARCH GO386 CGO_ENABLED;

  GOHOSTARCH = go.GOHOSTARCH or null;
  GOHOSTOS = go.GOHOSTOS or null;

  GOARM = toString (stdenv.lib.intersectLists [(stdenv.hostPlatform.parsed.cpu.version or "")] ["5" "6" "7"]);

  outputs = ["out" "man" "pause"];

  postPatch = ''
    substituteInPlace "hack/lib/golang.sh" --replace "_cgo" ""
    substituteInPlace "hack/lib/golang.sh" --replace "${cross-compilers.${go-target}}" "${stdenv.cc.targetPrefix}cc"
    substituteInPlace "hack/update-generated-docs.sh" --replace "make" "make SHELL=${stdenv.shell}"
    # hack/update-munge-docs.sh only performs some tests on the documentation.
    # They broke building k8s; disabled for now.
    echo "true" > "hack/update-munge-docs.sh"

    patchShebangs ./hack
  '';

  WHAT = concatStringsSep " " components;

  makeFlags = [
    "KUBE_BUILD_PLATFORMS=${go-target}"
  ];

  preBuild = ''
    export KUBE_VERBOSE=2
    export CC=${buildPackages.stdenv.cc}/bin/${buildPackages.stdenv.cc.targetPrefix}cc
    # export KUBE_BUILD_PLATFORMS
  '';

  postBuild = ''
    ./hack/update-generated-docs.sh
    (cd build/pause && ${buildPackages.stdenv.cc.targetPrefix}cc pause.c -o pause)
  '';

  installPhase = ''
    mkdir -p "$out/bin" "$out/share/bash-completion/completions" "$out/share/zsh/site-functions" "$man/share/man" "$pause/bin"

  '' + (if stdenv.buildPlatform == stdenv.hostPlatform then ''
    cp _output/local/go/bin/* "$out/bin/"
  '' else ''
    cp _output/local/go/bin/${go.GOOS}_${go.GOARCH}/* "$out/bin/"
  '') + ''
    cp build/pause/pause "$pause/bin/pause"
    cp -R docs/man/man1 "$man/share/man"

    cp cluster/addons/addon-manager/namespace.yaml $out/share
    cp cluster/addons/addon-manager/kube-addons.sh $out/bin/kube-addons
    patchShebangs $out/bin/kube-addons
    substituteInPlace $out/bin/kube-addons \
      --replace /opt/namespace.yaml $out/share/namespace.yaml
    wrapProgram $out/bin/kube-addons --set "KUBECTL_BIN" "$out/bin/kubectl"
  '' + lib.optionalString (stdenv.buildPlatform == stdenv.hostPlatform) ''
    $out/bin/kubectl completion bash > $out/share/bash-completion/completions/kubectl
    $out/bin/kubectl completion zsh > $out/share/zsh/site-functions/_kubectl
  '';

  preFixup = ''
    find $out/bin $pause/bin -type f -exec remove-references-to -t ${go.nativeDrv or go} '{}' +
  '';

  meta = {
    description = "Production-Grade Container Scheduling and Management";
    license = licenses.asl20;
    homepage = https://kubernetes.io;
    maintainers = with maintainers; [johanot offline];
    platforms = platforms.unix;
  };
}
