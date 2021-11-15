[![Gem Version](https://badge.fury.io/rb/maltese.svg)](https://badge.fury.io/rb/maltese)
[![Build Status](https://github.com/datacite/maltese/actions/workflows/build.yml/badge.svg)](https://github.com/datacite/maltese/actions/workflows/build.yml)
[![Code Climate](https://codeclimate.com/github/datacite/maltese/badges/gpa.svg)](https://codeclimate.com/github/datacite/maltese)
[![Test Coverage](https://codeclimate.com/github/datacite/maltese/badges/coverage.svg)](https://codeclimate.com/github/datacite/maltese/coverage)

# Maltese

Ruby gem and command-line tool for generating sitemap files from the DataCite REST API. Uses the [SitemapGenerator](https://github.com/kjvarga/sitemap_generator) gem and can be run as Docker container, e.g. using as a scheduled task in AWS ECS triggered by AWS Cloudwatch Events.

Run as a command-line tool:

```ruby
maltese sitemap
```

## Installation

Requires Ruby 2.2 or later. Then add the following to your `Gemfile` to install the
latest version:

```ruby
gem 'maltese'
```

Then run `bundle install` to install into your environment.

You can also install the gem system-wide in the usual way:

```bash
gem install maltese
```

## Development

We use rspec for unit testing:

```ruby
bundle exec rspec
```

Follow along via [Github Issues](https://github.com/datacite/toccatore/issues).

### Note on Patches/Pull Requests

* Fork the project
* Write tests for your new feature or a test that reproduces a bug
* Implement your feature or make a bug fix
* Do not mess with Rakefile, version or history
* Commit, push and make a pull request. Bonus points for topical branches.

## License

**maltese** is released under the [MIT License](https://github.com/datacite/maltese/blob/master/LICENSE.md).
