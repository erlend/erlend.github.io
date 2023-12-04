# frozen_string_literal: true

begin
  require "html-proofer"
  require "rubocop/rake_task"

  RuboCop::RakeTask.new do |rubocop|
    rubocop.formatters = ["github"] if ENV["CI"].to_s != ""
  end

  desc "Check HTML for errors"
  task :htmlproofer => :environment do
    output_dir = File.join(__dir__, SITE.fetch("destination", "_site"))
    Rake::Task["jekyll:build"].invoke if Dir.empty?(output_dir)

    base_url = SITE["base_url"]
    options = {
      :check_sri           => true,
      :check_external_hash => true,
      :check_html          => true,
      :check_img_http      => true,
      :check_opengraph     => true,
      :enforce_https       => true,
      :swap_urls           => base_url && "^/#{base_url}/:/",
    }

    proofer = HTMLProofer.check_directory(output_dir.to_s, options)
    proofer.run
  end

  multitask :all => [:htmlproofer, :rubocop]
  task :default => :all
rescue LoadError
  puts "Some dependencies are missing. Run `rake setup` to fix this."
end

task build: "jekyll:build"

task :environment do # rubocop:disable Rake/Desc
  require "bundler"
  require "uri"
  require "yaml"

  tailwindcss_path  = find_executable("tailwindcss") || "node_modules/.bin/tailwindcss"
  ENV["JEKYLL_MINIBUNDLE_CMD_CSS"] ||= File.expand_path(tailwindcss_path)
  ENV["JEKYLL_MINIBUNDLE_MODE"] ||= ENV.fetch("JEKYLL_ENV", nil)
  SITE = YAML.safe_load_file File.join(__dir__, "_config.yml")
end

desc "Setup build tools"
multitask :setup => %w(setup:bundler setup:pnpm)

desc "Run development server"
task :dev => :environment do
  if find_executable("docker") && system("docker compose version &>/dev/null")
    Rake::Task["dev_server:docker"].invoke
  else
    Rake::Task["dev_server:foreman"].invoke
  end
end

namespace :dev_server do
  desc "Run development server with Docker Compose"
  task :docker do
    args = ENV.fetch("DEV_SERVER_ARGS", "--build --quiet-pull")
    system!("docker compose up #{args}")
  end

  desc "Run development server with Foreman"
  task :foreman => :setup do
    find_executable("foreman") || system!("gem install foreman")
    args = ENV.fetch("DEV_SERVER_ARGS", nil)
    system!("foreman start #{args}")
  end
end

namespace :setup do
  desc "Install Ruby gems with Bundler"
  task :bundler do
    system("bundle check") || system!("bundle install")
  end

  desc "Install Node.js packages with pnpm"
  task :pnpm do
    system!("pnpm install")
  end
end

namespace :jekyll do
  desc "Build the site"
  task :build => :environment do
    system "bundle exec jekyll build"
  end

  task :serve => :environment do
    host = ENV["JEKYLL_HOST"]
    args = "--host #{host}" if host
    system "bundle exec jekyll serve --watch --livereload #{args}"
  end
end

namespace :tailwindcss do
  desc "Watch for changes and rebuild stylesheets"
  task :watch do
    system "pnpm run watch"
  end
end

def find_executable(command)
  ENV["PATH"].split(File::PATH_SEPARATOR).find do |path|
    command_path = File.join(path, command)
    command_path if File.executable?(command_path)
  end
end

def system!(*args)
  system(*args, :exception => true)
end
