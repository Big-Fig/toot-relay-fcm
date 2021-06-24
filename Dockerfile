FROM ruby:2.7
RUN mkdir /toot-relay-fcm
WORKDIR /toot-relay-fcm
COPY Gemfile /toot-relay-fcm/Gemfile
COPY Gemfile.lock /toot-relay-fcm/Gemfile.lock
RUN bundle install
COPY . /toot-relay-fcm
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]