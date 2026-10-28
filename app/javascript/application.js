// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
// pocket-kit's browser core first, so an error in anything after it is caught;
// it posts nothing unless the layout's pocket_kit_errors_tag named a path.
import "pocket_kit"
import "@hotwired/turbo-rails"
import "controllers"
