FROM ruby:4.0.6
WORKDIR /app
COPY Gemfile* ./
RUN bundle install
COPY . .
