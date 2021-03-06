# encoding: UTF-8

require "thor"
require_relative 'sitemap'

module Maltese
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    # from http://stackoverflow.com/questions/22809972/adding-a-version-option-to-a-ruby-thor-cli
    map %w[--version -v] => :__print_version

    desc "--version, -v", "print the version"
    def __print_version
      puts Toccatore::VERSION
    end

    desc "sitemap", "generate sitemap for DataCite Commons"
    method_option :sitemap_bucket, type: :string
    method_option :rack_env, type: :string
    method_option :access_key, type: :string
    method_option :secret_key, type: :string
    method_option :region, type: :string
    method_option :slack_webhook_url, type: :string
    def sitemap
      sitemap = Maltese::Sitemap.new(options)
      sitemap.queue_jobs
    end

    desc "datafile", "generate datafile for DataCite"
    method_option :datafile_bucket, type: :string
    method_option :rack_env, type: :string
    method_option :access_key, type: :string
    method_option :secret_key, type: :string
    method_option :region, type: :string
    method_option :slack_webhook_url, type: :string
    def datafile
      datafile = Maltese::Datafile.new(options)
      datafile.queue_jobs
    end
  end
end
