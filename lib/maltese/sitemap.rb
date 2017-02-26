require_relative 'base'

module Maltese
  class Sitemap < Base
    def query
      "*:*"
    end

    def parse_data(result, options={})
      return result.body.fetch("errors") if result.body.fetch("errors", nil).present?

      sitemap = options[:sitemap] || SitemapGenerator::LinkSet.new(default_host: sitemap_url)
      items = result.body.fetch("data", {}).fetch('response', {}).fetch('docs', nil)
      Array(items).each do |item|
        loc = "/works/" + item.fetch("doi")
        sitemap.add loc, changefreq: "monthly", lastmod: item.fetch("updated")
      end
      sitemap.sitemap.link_count
    end

    def push_data(items, options={})
      if items.empty?
        puts "No works found for date range #{options[:from_date]} - #{options[:until_date]}."
      # elsif options[:access_token].blank?
      #   puts "An error occured: Access token missing."
      else

      end
    end
  end
end
