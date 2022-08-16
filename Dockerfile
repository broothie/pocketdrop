FROM ruby:3.1.2

WORKDIR /usr/src/app
COPY Gemfile Gemfile.lock puma.rb config.ru server.rb ./
COPY views views

RUN gem install bundler -v 2.3.7
RUN bundle config set without development
RUN bundle

CMD ["bundle", "exec", "puma", "-C", "puma.rb"]
