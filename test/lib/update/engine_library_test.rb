require "test_helper"

# A BUILT EXTENSION IS RENAMED INTO PLACE: a process holding the old library
# keeps its bytes, and the target holds the new ones.
class Update::EngineLibraryTest < ActiveSupport::TestCase
  test "the old library's inode and bytes survive; the target holds the new bytes" do
    Dir.mktmpdir do |dir|
      library = File.join(dir, "built.so")
      target = File.join(dir, "renderedstep_native.so")
      File.binwrite(library, "new engine")
      File.binwrite(target, "old engine")

      File.open(target, "rb") do |loaded|
        inode = loaded.stat.ino
        Update::EngineLibrary.install!(library, target)

        assert_equal inode, loaded.stat.ino
        loaded.rewind
        assert_equal "old engine", loaded.read
        refute_equal inode, File.stat(target).ino
        assert_equal "new engine", File.binread(target)
      end
      assert_equal %w[built.so renderedstep_native.so], Dir.children(dir).sort
    end
  end

  test "a failed copy leaves the target as it was and no temporary file behind" do
    Dir.mktmpdir do |dir|
      target = File.join(dir, "renderedstep_native.so")
      File.binwrite(target, "old engine")

      assert_raises(Errno::ENOENT) { Update::EngineLibrary.install!(File.join(dir, "missing.so"), target) }
      assert_equal "old engine", File.binread(target)
      assert_equal %w[renderedstep_native.so], Dir.children(dir)
    end
  end

  test "engine:build installs cargo's library by rename, with cargo stubbed" do
    require "rake"
    Rails.application.load_tasks unless Rake::Task.task_defined?("engine:build")
    task = Rake::Task["engine:build"]
    task.reenable
    installed = nil
    cargo = ->(*arguments, **) { assert_equal "cargo", arguments.first }
    TOPLEVEL_BINDING.receiver.stub(:system, cargo) do
      Dir.stub(:[], [ "/crate/target/release/librenderedstep_native.so" ]) do
        FileUtils.stub(:mkdir_p, nil) do
          Update::EngineLibrary.stub(:install!, ->(library, built) { installed = [ library, built ] }) do
            Update::EngineStamp.stub(:write!, nil) { capture_io { task.invoke } }
          end
        end
      end
    end

    assert_equal "/crate/target/release/librenderedstep_native.so", installed.first
    assert_match %r{ext/renderedstep/build/renderedstep_native\.}, installed.last
  end
end
