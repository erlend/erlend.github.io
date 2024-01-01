FROM ruby:3.3 as base

ENV PNPM_HOME=/usr/local/pnpm
ENV PATH="$PNPM_HOME:$PATH"

# Install pnpm and NodeJS
RUN curl -fsSL https://get.pnpm.io/install.sh | SHELL=bash sh - \
 && pnpm env add --global lts \
 && ln -s $PNPM_HOME/nodejs/*/bin/node /usr/local/bin/ \
 && rm /root/.bashrc

FROM base AS build
ENV JEKYLL_ENV=production
WORKDIR /code

# Install Node.js packages
# Install dependencies
COPY _config.yml Rakefile Gemfile Gemfile.lock package.json pnpm-lock.yaml ./
RUN rake setup

# Build site
COPY . .
RUN rake build

# Create release stage
FROM nginx:1
COPY --from=build /code/_site /usr/share/nginx/html
