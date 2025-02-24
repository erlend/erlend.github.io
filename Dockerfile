FROM jdxcode/mise AS base
ENV MISE_EXPERIMENTAL=true
ENV MISE_TRUSTED_CONFIG_PATHS=/code
WORKDIR /code

FROM base AS build
ENV JEKYLL_ENV=production

# Install Node.js packages
# Install dependencies
COPY mise.toml Gemfile Gemfile.lock package.json pnpm-lock.yaml ./
RUN mise run setup

# Build site
COPY . .
RUN mise run build

# Create release stage
FROM nginx:1
COPY --from=build /code/_site /usr/share/nginx/html
