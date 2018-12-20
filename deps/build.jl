using BinDeps
using Compat

if isdefined((@static VERSION < v"0.7.0-DEV.484" ? current_module() : @__MODULE__), :Compat)
    import Compat.Libdl
elseif VERSION >= v"0.7.0-DEV.3382"
    import Libdl
end

@BinDeps.setup

libopus = library_dependency("libopus", aliases = ["libopus"])

@static if Sys.isapple()
  using Homebrew
  provides( Homebrew.HB, "opus", libopus, os = :Darwin )
end

provides( AptGet, "libopus0", libopus )

# Source build
provides( Sources,
          URI("http://downloads.xiph.org/releases/opus/opus-1.1.2.tar.gz"),
          SHA="0e290078e31211baa7b5886bcc8ab6bc048b9fc83882532da4a1a45e58e907fd",
          libopus )
provides( BuildProcess,
          Autotools(libtarget=".libs/libopus."*Libdl.dlext, configure_options = ["--libdir=$(BinDeps.libdir(libopus))"]),
          libopus )

@compat @BinDeps.install Dict(:libopus => :libopus)
