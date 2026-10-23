require "test_helper"

# THE ICONS ARE STATIC FILES IN public/, linked from every full-page layout.
# This checks each one is served with the type a browser needs to use it.
class IconsTest < ActionDispatch::IntegrationTest
  ICONS = {
    "/icon.svg" => "image/svg+xml",
    "/favicon.ico" => "image/vnd.microsoft.icon",
    "/apple-touch-icon.png" => "image/png",
    "/icon-192.png" => "image/png",
    "/icon-512.png" => "image/png",
    "/manifest.json" => "application/json"
  }.freeze

  test "every icon and the manifest is served with its content type" do
    ICONS.each do |path, type|
      get path
      assert_response :ok, path
      assert_equal type, response.media_type, path
    end
  end

  test "the manifest names only icons that exist" do
    manifest = JSON.parse(Rails.public_path.join("manifest.json").read)

    assert_equal "Text Adventure", manifest["name"]
    manifest["icons"].each { |icon| assert Rails.public_path.join(icon["src"].delete_prefix("/")).file?, icon["src"] }
  end

  test "the play page links the icons" do
    get root_path

    assert_select "link[rel=icon][href='/icon.svg']"
    assert_select "link[rel=icon][href='/favicon.ico']"
    assert_select "link[rel=apple-touch-icon][href='/apple-touch-icon.png']"
    assert_select "link[rel=manifest][href='/manifest.json']"
    assert_select "meta[name=theme-color]"
  end
end
