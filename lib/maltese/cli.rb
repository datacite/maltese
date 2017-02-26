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

    desc "sitemap", "generate sitemap"
    # method_option :access_token, type: :string, required: true
    # method_option :push_url, type: :string
    method_option :from_date, type: :string, default: (Time.now.to_date - 1.day).iso8601
    method_option :until_date, type: :string, default: Time.now.to_date.iso8601
    def sitemap
      sitemap = Maltese::Sitemap.new
      sitemap.queue_jobs(sitemap.unfreeze(options))
    end
  end
end
