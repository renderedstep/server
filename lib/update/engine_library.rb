# PUTTING A BUILT ENGINE EXTENSION IN PLACE, without writing into the old one.
#
# THE BUG IT IS FOR. `engine:build` used to `FileUtils.cp` cargo's library over
# `ext/renderedstep/build/renderedstep_native.so`. A copy writes into the
# existing file, so every running process that had it loaded -- the web server
# and the job processes of the deployed app -- now had new bytes mapped where
# its old code was. Nothing failed until the restart that the build asks for:
# each process ran its exit handlers on the way down, jumped into replaced
# code, and segfaulted. One crash per process, on every deploy.
#
# So the new library is written to a temporary file in the same directory and
# renamed over the target. A rename swaps the directory entry in one step; the
# old inode lives on, untouched, for every process that still maps it, and the
# next `require` reads the new one. Same directory, because a rename across
# filesystems is a copy. A failed copy leaves the target as it was and no
# temporary file behind.
#
# PLAIN RUBY, no Rails: `engine:build` requires this without booting the app.
require "fileutils"
require "securerandom"

module Update
  module EngineLibrary
    def self.install!(library, target)
      temporary = File.join(File.dirname(target), ".#{File.basename(target)}.#{SecureRandom.hex(6)}.tmp")
      FileUtils.cp(library, temporary)
      File.rename(temporary, target)
      target
    ensure
      FileUtils.rm_f(temporary) if temporary && File.exist?(temporary)
    end
  end
end
