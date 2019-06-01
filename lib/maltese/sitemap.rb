module Maltese
  class Sitemap
    attr_reader :sitemap_bucket

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
    end

    def sitemap_url
      ENV['RACK_ENV'] == "production" ? "https://search.datacite.org/" : "https://search.test.datacite.org/"
    end

    def sitemaps_path
      "sitemaps/"
    end

    def search_path
      ENV['RACK_ENV'] == "production" ? "https://api.datacite.org/dois?" : "https://api.test.datacite.org/dois?"
    end

    def timeout
      120
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
                                      aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
                                      aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
                                      aws_region: ENV['AWS_REGION'])
    end

    def queue_jobs(options={})
      total = get_total(options)

      if total > 0
        puts process_data(options.merge(total: total, url: get_query_url))
      else
        puts "No works found."
      end

      # return number of works queued
      total
    end

    def get_total(options={})
      query_url = get_query_url(options.merge(size: 0))

      result = Maremma.get(query_url, options)
      result.body.dig("meta", "total")
    end

    def get_query_url(options={})
      options[:cursor] = options[:cursor] || 1
      options[:size] = options[:size] || job_batch_size

      params = { 
        "page[cursor]": options[:cursor],
        "page[size]": options[:size],
      }
      search_path + URI.encode_www_form(params)
    end

    def process_data(options = {})
      options[:start_time] = Time.now

      # walk through paginated results
      while options[:url] do
        response = get_data(options[:url])
        parse_data(response)
        options[:url] = response.body.dig("links", "next")

        # don't loop when testing
        break if ENV['RACK'] == "test"     
      end

      push_data(options)
    end

    def get_data(url)
      Maremma.get(url)
    end

    def parse_data(result)
      return result.body.fetch("errors") if result.body.fetch("errors", nil).present?

      result.body.fetch("data", []).each do |item|
        loc = "/works/" + item.dig("attributes", "doi")
        sitemap.add loc, changefreq: "monthly", lastmod: item.dig("attrributes", "updated")
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
