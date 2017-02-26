module Maltese
  class Base
    # load ENV variables from .env file if it exists
    env_file = File.expand_path("../../../.env", __FILE__)
    if File.exist?(env_file)
      require 'dotenv'
      Dotenv.load! env_file
    end

    # load ENV variables from container environment if json file exists
    # see https://github.com/phusion/baseimage-docker#envvar_dumps
    env_json_file = "/etc/container_environment.json"
    if File.size?(env_json_file).to_i > 2
      env_vars = JSON.parse(File.read(env_json_file))
      env_vars.each { |k, v| ENV[k] = v }
    end

    def get_query_url(options={})
      from_date = options[:from_date].presence || (Time.now.to_date - 1.day).iso8601
      until_date = options[:until_date].presence || Time.now.to_date.iso8601

      params = { offset: options[:offset],
                 rows: options[:rows],
                 "from-update-date" => from_date,
                 "until-update-date" => until_date,
                 sort: "updated",
                 order: "asc" }
      url +  URI.encode_www_form(params)
    end

    def get_total(options={})
      query_url = get_query_url(options.merge(rows: 0))
      result = Maremma.get(query_url, options)
      result.body.fetch("meta", {}).fetch("total", 0)
    end

    def queue_jobs(options={})
      options[:offset] = options[:offset].to_i || 0
      options[:rows] = options[:rows].presence || job_batch_size
      options[:from_date] = options[:from_date].presence || (Time.now.to_date - 1.day).iso8601
      options[:until_date] = options[:until_date].presence || Time.now.to_date.iso8601

      total = get_total(options)

      if total > 0
        process_data(options.merge(total: total))
      else
        puts "No works found for date range #{options[:from_date]} - #{options[:until_date]}."
      end

      # return number of works queued
      total
    end

    def process_data(options = {})
      # walk through paginated results
      total_pages = (options[:total].to_f / job_batch_size).ceil

      (0...total_pages).each do |page|
        options[:offset] = page * job_batch_size
        data = get_data(options.merge(timeout: timeout))
        parse_data(data, sitemap: sitemap)
      end

      sitemap.finalize!

      #return [OpenStruct.new(body: { "data" => [] })] if data.empty?

      #push_data(data, options)
    end

    def get_data(options={})
      query_url = get_query_url(options)
      Maremma.get(query_url, options)
    end

    def config_fields
      [:url, :push_url, :access_token]
    end

    def sitemap
      @sitemap ||= SitemapGenerator::LinkSet.new(default_host: sitemap_url, finalize: false)
    end

    def url
      ENV['API_URL'].presence || "https://api.datacite.org/works?"
    end

    def sitemap_url
      ENV['SITEMAP_URL'].presence || "https://search.datacite.org"
    end

    def timeout
      120
    end

    def job_batch_size
      1000
    end

    def unfreeze(hsh)
      new_hash = {}
      hsh.each_pair { |k,v| new_hash.merge!({k.downcase.to_sym => v})  }
      new_hash
    end
  end
end
