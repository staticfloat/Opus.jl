using BinDeps
using Compat

@BinDeps.setup

libopus = library_dependency("libopus", aliases = ["libopus"])

@osx_only begin
  using Homebrew
  provides( Homebrew.HB, "opus", libopus, os = :Darwin )
end

provides( AptGet, "libopus0", libopus )

@compat @BinDeps.install Dict(:libopus => :libopus)
