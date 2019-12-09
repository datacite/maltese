FROM phusion/passenger-full:0.9.30
LABEL maintainer="mfenner@datacite.org"

# Install Ruby 2.4.4
RUN bash -lc 'rvm --default use ruby-2.4.4'

ENV PATH="/usr/local/rvm/gems/ruby-2.4.4/bin:${PATH}"

# Update installed APT packages, clean up APT when done.
RUN apt-get update && apt-get upgrade -y -o Dpkg::Options::="--force-confold" && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install maltese gem
RUN /sbin/setuser app gem install maltese -v 0.8.10

CMD maltese sitemap --sitemap_bucket $SITEMAP_BUCKET
