# frozen_string_literal: true

Jekyll::Hooks.register :site, :pre_render do |payload|
  imports = payload.data.dig("importmap", "imports")
  Dir["**/*.js", :base => "_assets/javascripts"].each do |path|
    key = File.join(".", path).delete_suffix(".js")
    imports[key] = File.join("_assets/javascripts", path)
  end
end
