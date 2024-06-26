require "date"
require File.expand_path("../lib/maltese/version", __FILE__)

Gem::Specification.new do |s|
  s.authors       = "Martin Fenner"
  s.email         = "mfenner@datacite.org"
  s.name          = "maltese"
  s.homepage      = "https://github.com/datacite/maltese"
  s.summary       = "Ruby library to generate sitemap for DataCite Commons"
  s.date          = Date.today
  s.description   = "Ruby library to generate sitemap for DataCite Commons."
  s.require_paths = ["lib"]
  s.version       = Maltese::VERSION
  s.extra_rdoc_files = ["README.md"]
  s.license       = 'MIT'

  # Declary dependencies here, rather than in the Gemfile
  s.add_dependency 'maremma', '~> 5.0'
  s.add_dependency 'faraday', '~> 2.9'
  s.add_dependency 'logstash-logger', '~> 0.26.1'
  s.add_dependency 'activesupport', '~> 7.1', '>= 7.1.3.2'
  s.add_dependency 'dotenv', '~> 2.1', '>= 2.1.1'
  s.add_dependency 'slack-notifier', '~> 2.1'
  s.add_dependency 'thor', '~> 0.19'
  s.add_dependency 'retriable', '~> 3.1'
  s.add_dependency 'sitemap_generator', '~> 6.0'
  s.add_dependency 'aws-sdk-s3', '~> 1.19'
  s.add_dependency 'mime-types', '~> 3.1'
  s.add_dependency 'rexml', '~> 3.2', '>= 3.2.6'
  s.add_dependency 'webrick', '~> 1.8', '>= 1.8.1'
  s.add_development_dependency 'bundler', '~> 2.0'
  s.add_development_dependency 'rspec', '~> 3.13'
  s.add_development_dependency 'rake', '~> 12.0'
  s.add_development_dependency 'rack-test', '~> 0'
  s.add_development_dependency 'vcr', '~> 6.1'
  s.add_development_dependency 'webmock', '~> 3.23'
  s.add_development_dependency 'codeclimate-test-reporter', '~> 1.0', '>= 1.0.8'
  s.add_development_dependency 'simplecov', '0.13'

  s.require_paths = ["lib"]
  s.files       = `git ls-files`.split($/)
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = ["maltese"]
end
