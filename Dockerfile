# syntax=docker/dockerfile:1

ARG RUBY_VERSION=4.0
ARG BUNDLER_VERSION=4.0.6

FROM ruby:${RUBY_VERSION}-alpine AS gems
ARG BUNDLER_VERSION
WORKDIR /app
ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test \
    RACK_ENV=production
RUN gem install bundler:${BUNDLER_VERSION} --no-document && \
    apk add --no-cache build-base
COPY Gemfile Gemfile.lock ./
RUN --mount=type=cache,target=/usr/local/bundle/cache \
    bundle install && \
    rm -rf /usr/local/bundle/cache/*.gem /usr/local/bundle/ruby/*/cache

FROM ruby:${RUBY_VERSION}-alpine
WORKDIR /app
ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test \
    RACK_ENV=production
RUN addgroup -S app && adduser -S app -G app
COPY --from=gems /usr/local/bundle /usr/local/bundle
COPY --chown=app:app . .
USER app
EXPOSE 9292
CMD ["bundle", "exec", "puma", "-b", "tcp://0.0.0.0:9292", "config.ru"]
