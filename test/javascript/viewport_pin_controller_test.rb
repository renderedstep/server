require "test_helper"
require "open3"
require "tmpdir"

# THE PINNED HEADER STAYS AT THE TOP when the page is pulled past its bottom.
#
# Reported from an iPhone home-screen app with the keyboard open: scrolled to
# the bottom, a further pull moved the header down the screen, apart from the
# top. `visualViewport.offsetTop` grows during that rubber-band pull, and the
# pin followed it. This drives the real `viewport_pin_controller.js` in
# headless Chrome at the reported 375x524 layout viewport, with a stand-in
# `visualViewport` reporting what iOS reports, and reads back the header's
# top. `innerHeight` is pinned to that layout height too, since a headless
# window spends some of its own on browser chrome. There is no system-test stack here, so the page is a static harness
# loaded from a temporary directory and the result comes out of `--dump-dom`.
#
# What headless Chrome cannot do is the iOS rubber band itself: it has no
# elastic overscroll and no on-screen keyboard, so the numbers iOS reports are
# supplied by hand. The test pins the arithmetic, not Safari.
class ViewportPinControllerTest < ActiveSupport::TestCase
  CONTROLLER = Rails.root.join("app/javascript/controllers/viewport_pin_controller.js")
  LAYOUT_HEIGHT = 524

  setup do
    @chrome = %w[chromium chromium-browser google-chrome].lazy.map { |c| `command -v #{c} 2>/dev/null`.strip }.find(&:present?)
    skip "no headless Chrome on this machine" unless @chrome
  end

  test "with the keyboard open the header follows the visible top" do
    assert_equal 178, header_top(height: 346, offset_top: 178)
  end

  test "with the keyboard open an overscroll past the bottom does not move the header down" do
    assert_equal 178, header_top(height: 346, offset_top: 240)
  end

  test "with the keyboard shut an overscroll past the bottom leaves the header at the top" do
    assert_equal 0, header_top(height: LAYOUT_HEIGHT, offset_top: 60)
  end

  test "a negative offset from a pull past the top leaves the header at the top" do
    assert_equal 0, header_top(height: LAYOUT_HEIGHT, offset_top: -40)
  end

  private

  # How far below the layout top the controller moves the header, in px.
  def header_top(height:, offset_top:)
    Dir.mktmpdir do |dir|
      FileUtils.cp(CONTROLLER, File.join(dir, "controller.js"))
      File.write(File.join(dir, "stimulus.js"), "export class Controller { constructor(element) { this.element = element } }\n")
      File.write(File.join(dir, "index.html"), harness(height, offset_top))

      out, err, status = Open3.capture3(@chrome, "--headless", "--no-sandbox", "--disable-gpu",
        "--allow-file-access-from-files", "--window-size=375,#{LAYOUT_HEIGHT}",
        "--virtual-time-budget=2000", "--dump-dom", "file://#{dir}/index.html")
      assert status.success?, err
      result = out[/data-result="([^"]*)"/, 1]
      assert result, "harness reported nothing: #{err.lines.last(5).join}"
      flunk "harness failed: #{result}" unless result.match?(/\A-?\d+(\.\d+)?\z/)
      result.to_f.round
    end
  end

  def harness(height, offset_top)
    <<~HTML
      <!doctype html>
      <script type="importmap">{"imports":{"@hotwired/stimulus":"./stimulus.js"}}</script>
      <header id="h" style="position:sticky;top:0">header</header>
      <script type="module">
        try {
          const listeners = {}
          const viewport = {
            height: #{height}, offsetTop: #{offset_top},
            addEventListener(type, fn) { listeners[type] = fn },
            removeEventListener() {}
          }
          Object.defineProperty(window, "visualViewport", { value: viewport, configurable: true })
          Object.defineProperty(window, "innerHeight", { value: #{LAYOUT_HEIGHT}, configurable: true })
          const { default: Pin } = await import("./controller.js")
          const header = document.getElementById("h")
          new Pin(header).connect()
          listeners.scroll()
          document.body.dataset.result = String(new DOMMatrix(getComputedStyle(header).transform).m42)
        } catch (e) {
          document.body.dataset.result = "error: " + e
        }
      </script>
    HTML
  end
end
