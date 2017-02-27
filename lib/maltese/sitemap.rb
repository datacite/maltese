module Maltese
  class Sitemap
    attr_reader :sitemap_bucket, :from_date, :until_date

    # load ENV variables from container environment if json file exists
    # see https://github.com/phusion/baseimage-docker#envvar_dumps
    env_json_file = "/etc/container_environment.json"
    if File.size?(env_json_file).to_i > 2
      env_vars = JSON.parse(File.read(env_json_file))
      env_vars.each { |k, v| ENV[k] = v }
    end

    def initialize(attributes={})
      @sitemap_bucket = attributes[:sitemap_bucket].presence || "search.datacite.org"
      @from_date = attributes[:from_date].presence || (Time.now.to_date - 1.day).iso8601
      @until_date = attributes[:until_date].presence || Time.now.to_date.iso8601
    end

    def sitemap_url
      "https://#{sitemap_bucket}"
    end

    def search_path
      "#{sitemap_url}/api?"
    end

    def sitemaps_path
      ENV['RACK'] == "test" ? 'sitemaps-test' : 'sitemaps/'
    end

    def timeout
      120
    end

    def job_batch_size
      50000
    end

    def sitemap
      @sitemap ||= SitemapGenerator::LinkSet.new(
        default_host: sitemap_url,
        sitemaps_host: sitemap_url,
        adapter: s3_adapter,
        sitemaps_path: sitemaps_path,
        finalize: false)
    end

    def s3_adapter
      SitemapGenerator::S3Adapter.new(fog_provider: 'AWS',
                                      aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
                                      aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
                                      fog_region: ENV['AWS_REGION'],
                                      fog_directory: sitemap_bucket,
                                      path_style: true)
    end

    def fog_storage
      Fog::Storage.new(provider: 'AWS',
                       aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
                       aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'])
    end

    def queue_jobs(options={})
      total = get_total(options)

      if total > 0
        puts process_data(options.merge(total: total))
      else
        puts "No works found for date range #{from_date} - #{until_date}."
      end

      # return number of works queued
      total
    end

    def get_total(options={})
      query_url = get_query_url(options.merge(rows: 0))
      result = Maremma.get(query_url, options)
      result.body.fetch("data", {}).fetch("response", {}).fetch("numFound", 0)
    end

    def get_query_url(options={})
      options[:offset] = options[:offset].to_i || 0
      options[:rows] = options[:rows].presence || job_batch_size

      updated = "updated:[#{from_date}T00:00:00Z TO #{until_date}T23:59:59Z]"
      fq = "#{updated} AND has_metadata:true AND is_active:true"

      params = { q: "*:*",
                 fq: fq,
                 start: options[:offset],
                 rows: options[:rows],
                 fl: "doi,updated",
                 sort: "updated asc",
                 wt: "json" }
      search_path + URI.encode_www_form(params)
    end

    def process_data(options = {})
      options[:start_time] = Time.now

      # walk through paginated results
      total_pages = (options[:total].to_f / job_batch_size).ceil

      (0...total_pages).each do |page|
        options[:offset] = page * job_batch_size
        data = get_data(options.merge(timeout: timeout))
        parse_data(data)
      end

      push_data(options)
    end

    def get_data(options={})
      query_url = get_query_url(options)
      Maremma.get(query_url, options)
    end

    def parse_data(result)
      return result.body.fetch("errors") if result.body.fetch("errors", nil).present?

      items = result.body.fetch("data", {}).fetch('response', {}).fetch('docs', nil)
      Array(items).each do |item|
        loc = "/works/" + item.fetch("doi")
        sitemap.add loc, changefreq: "monthly", lastmod: item.fetch("updated")
      end
      sitemap.sitemap.link_count
    end

    def push_data(options={})
      # sync time with AWS S3 before uploading
      fog_storage.sync_clock

      sitemap.finalize!
      options[:start_time] ||= Time.now
      sitemap.sitemap_index.stats_summary(:time_taken => Time.now - options[:start_time])
      sitemap.sitemap.link_count
    end
  end
end
