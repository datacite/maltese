require 'spec_helper'
require 'maltese/cli'

describe Maltese::CLI do
  let(:subject) do
    described_class.new
  end

  let(:from_date) { "2015-04-07" }
  let(:until_date) { "2015-04-08" }
  let(:sitemap_bucket) { "search.test.datacite.org" }
  let(:cli_options) { { sitemap_bucket: sitemap_bucket,
                        from_date: from_date,
                        until_date: until_date } }

  describe "sitemap", vcr: true, :order => :defined do
    it 'should succeed' do
      subject.options = cli_options
      expect { subject.sitemap }.to output(/2522 links/).to_stdout
      sitemap = Zlib::GzipReader.open("public/sitemap.xml.gz") { |gz| gz.read }
      doc = Nokogiri::XML(sitemap)
      expect(doc.xpath("//xmlns:url").size).to eq(2522)
      expect(doc.xpath("//xmlns:loc").last.text).to eq("https://search.datacite.org/works/10.6084/M9.FIGSHARE.1371139")
    end

    it 'should succeed with no works' do
      from_date = "2005-04-07"
      until_date = "2005-04-08"
      subject.options = { sitemap_bucket: sitemap_bucket,
                          from_date: from_date,
                          until_date: until_date }
      expect { subject.sitemap }.to output("No works found for date range 2005-04-07 - 2005-04-08.\n").to_stdout
    end
  end
end
