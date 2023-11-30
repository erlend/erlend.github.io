# frozen_string_literal: true

TAILWIND_VERSION = ENV.fetch("TAILWIND_VERSION", "3.3.5")

begin
  require "html-proofer"
  require "rubocop/rake_task"

  RuboCop::RakeTask.new do |rubocop|
    rubocop.formatters = ["github"] if ENV["CI"].to_s != ""
  end

  desc "Check HTML for errors"
  task :htmlproofer => :configuration do
    output_dir = @root.join @site.fetch("destination", "_site")
    Rake::Task["build"].invoke if Dir.empty?(output_dir)

    base_url = @site["base_url"]
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
  puts "Could not load test suite."
end

task :configuration do # rubocop:disable Rake/Desc
  require "bundler"
  require "mkmf"
  require "pathname"
  require "uri"
  require "yaml"

  @root = Pathname.new(__dir__)
  @site = YAML.safe_load_file @root.join("_config.yml")
end

task :environment => :configuration do # rubocop:disable Rake/Desc
  path = MakeMakefile.find_executable("tailwindcss") ||
    ENV.fetch("TAILWIND_BIN", "vendor/bin/tailwindcss")

  @tailwindcss = path.start_with?("/") ? Pathname.new(path) : @root.join(path)

  ENV["JEKYLL_MINIBUNDLE_MODE"] ||= ENV.fetch("JEKYLL_ENV", nil)
  ENV["JEKYLL_MINIBUNDLE_CMD_CSS"] ||= @tailwindcss.expand_path.to_s
end

desc "Build the site"
task :build => :environment do
  system "bundle exec jekyll build"
end

desc "Setup build tools"
multitask :setup => %w(setup:bundler setup:tailwindcss)

desc "Run development server"
task :dev => :configuration do
  if MakeMakefile.find_executable("docker") && system("docker compose version &>/dev/null")
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
    MakeMakefile.find_executable("foreman") || system!("gem install foreman")
    args = ENV.fetch("DEV_SERVER_ARGS", nil)
    system!("foreman start #{args}")
  end
end

namespace :setup do
  desc "Install Ruby gems with Bundler"
  task :bundler do
    require "bundler"
    system("bundle check") || system!("bundle install")
  end

  desc "Download TailwindCSS"
  task :tailwindcss => :environment do
    next if @tailwindcss.exist?

    Bundler.mkdir_p @tailwindcss.dirname
    @tailwindcss.open("wb", 0o755) { |file| file << download_tailwindcss }
  end
end

def download_tailwindcss
  require "net/https"

  arch, os = RUBY_PLATFORM.split("-")
  arch = "arm64" if arch == "aarch64"
  arch = "x64" if arch == "x86_64"
  os = "macos" if os.start_with?("darwin")
  puts "=> Downloading TailwindCSS #{TAILWIND_VERSION} for #{arch}-#{os}"

  uri = URI "https://github.com/tailwindlabs/tailwindcss/releases/download/" \
            "v#{TAILWIND_VERSION}/tailwindcss-#{os}-#{arch}"

  response = Net::HTTP.get_response(uri)
  case response.code.to_i
  when 200
    response.body
  when 300..399
    uri = URI response["Location"]
    Net::HTTP.get(uri)
  else
    raise "Unable to download TailwindCSS CLI"
  end
end

def system!(*args)
  system(*args, :exception => true)
end
