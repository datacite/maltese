require "logger"

module Maltese
  class Sitemap
    attr_reader :sitemap_bucket, :rack_env, :access_key, :secret_key, :region, :logger

    # load ENV variables from .env file if it exists
    env_file = File.expand_path("../../../.env", __FILE__)
    if File.exist?(env_file)
      require 'dotenv'
      Dotenv.overload env_file
    end

    # load ENV variables from container environment if json file exists
    # see https://github.com/phusion/baseimage-docker#envvar_dumps
    env_json_file = "/etc/container_environment.json"
    if File.size?(env_json_file).to_i > 2
      env_vars = JSON.parse(File.read(env_json_file))
      env_vars.each { |k, v| ENV[k] = v }
    end

    def initialize(attributes={})
      @sitemap_bucket = attributes[:sitemap_bucket].presence || "search.test.datacite.org"
      @rack_env = attributes[:rack_env].presence || ENV['RACK_ENV'] || "stage"
      @access_key = attributes[:access_key].presence || ENV['AWS_ACCESS_KEY_ID']
      @secret_key = attributes[:secret_key].presence || ENV['AWS_SECRET_ACCESS_KEY']
      @region = attributes[:region].presence || ENV['AWS_REGION']

      @logger = Logger.new(STDOUT)
    end

    def sitemap_url
      rack_env == "production" ? "https://search.datacite.org/" : "https://search.test.datacite.org/"
    end

    def sitemaps_path
      "sitemaps/"
    end

    def search_path
      rack_env == "production" ? "https://api.datacite.org/dois?" : "https://api.test.datacite.org/dois?"
    end

    def timeout
      60
    end

    def job_batch_size
      1000
    end

    def sitemap
      @sitemap ||= SitemapGenerator::LinkSet.new(
        default_host: sitemap_url,
        sitemaps_host: sitemap_url,
        sitemaps_path: sitemaps_path,
        adapter: s3_adapter,
        finalize: false)
    end

    def s3_adapter
      SitemapGenerator::AwsSdkAdapter.new(sitemap_bucket,
                                      aws_access_key_id: access_key,
                                      aws_secret_access_key: secret_key,
                                      aws_region: region)
    end

    def queue_jobs(options={})
      total = get_total(options)

      if total.nil?
        logger.error "An error occured."
      elsif total > 0
        process_data(options.merge(total: total, url: get_query_url))
      else
        logger.info "No works found."
      end

      # return number of works queued
      total.to_i
    end

    def get_total(options={})
      query_url = get_query_url(options.merge(size: 1))

      result = Maremma.get(query_url, options)
      result.body.dig("meta", "total")
    end

    def get_query_url(options={})
      options[:size] = options[:size] || job_batch_size

      params = { 
        "fields[dois]" => "doi,updated",
        "page[scroll]" => "7m",
        "page[size]" => options[:size]
      }
      search_path + URI.encode_www_form(params)
    end

    def process_data(options = {})
      options[:start_time] = Time.now
      link_count = 0
      error_count = 0

      # walk through paginated results
      while options[:url] do
        response = get_data(options[:url])

        if response.status == 200
          link_count += parse_data(response)
          logger.info "#{link_count} DOIs parsed."
          options[:url] = response.body.dig("links", "next")
        else
          logger.error "An error occured for URL #{options[:url]}."
          logger.error "Error message: #{response.body.fetch("errors").inspect}" if response.body.fetch("errors", nil).present?
          error_count += 1
          options[:url] = nil
        end 

        # don't loop when testing
        break if rack_env == "test"     
      end

      return link_count if error_count > 0

      push_data(options)
    end

    def get_data(url)
      Maremma.get(url, timeout: 300)
    end

    def parse_data(result)
      Array.wrap(result.body.fetch("data", nil)).each do |item|
        loc = "/works/" + item.dig("attributes", "doi")
        sitemap.add loc, changefreq: "monthly", lastmod: item.dig("attributes", "updated")
      end
      sitemap.sitemap.link_count
    end

    def push_data(options={})
      sitemap.finalize!
      options[:start_time] ||= Time.now
      sitemap.sitemap_index.stats_summary(:time_taken => Time.now - options[:start_time])
      sitemap.sitemap.link_count
    end
  end
end
