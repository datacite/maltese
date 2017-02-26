require_relative 'base'

module Maltese
  class Sitemap < Base
    def parse_data(result, options={})
      return result.body.fetch("errors") if result.body.fetch("errors", nil).present?

      sitemap = options[:sitemap] || SitemapGenerator::LinkSet.new(default_host: sitemap_url)
      items = result.body.fetch("data", [])
      Array(items).each do |item|
        loc = "/works/" + item.dig("attributes", "doi")
        sitemap.add loc,
                    changefreq: "monthly",
                    lastmod: item.dig("attributes", "updated")
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
