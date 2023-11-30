# Should have the same version as .gitlab-ci.yml
FROM ruby:3.2 as base
ENV TAILWIND_BIN="/usr/local/bin/tailwindcss"
WORKDIR /code

FROM base AS dependencies

# Install additional system dependencies
# RUN apt-get update \
#  && apt-get install --yes cowsay \
#  && rm -rf /var/lib/apt/lists/*

# Install Jekyll and plugins
COPY _config.yml Rakefile Gemfile Gemfile.lock ./
RUN bundle config build.nokogiri --use-system-libraries
RUN rake setup

# Build site
FROM base AS build
COPY --from=dependencies "$GEM_HOME" "$GEM_HOME"
COPY --from=dependencies "$TAILWIND_BIN" "$TAILWIND_BIN"
COPY . .
RUN JEKYLL_ENV=production rake build

# Create release stage
FROM nginx:1
COPY --from=build /code/_site /usr/share/nginx/html
