require 'spec_helper'
require 'maltese/cli'

describe Maltese::CLI do
  let(:subject) do
    described_class.new
  end

  let(:sitemap_bucket) { "search.test.datacite.org" }
  let(:cli_options) { { sitemap_bucket: sitemap_bucket, rack_env: "test" } }

  describe "sitemap", vcr: true, :order => :defined do
    it 'should succeed' do
      subject.options = cli_options
      expect { subject.sitemap }.to output(/1001 links/).to_stdout
      sitemap = Zlib::GzipReader.open("public/sitemaps/sitemap.xml.gz") { |gz| gz.read }
      doc = Nokogiri::XML(sitemap)
      expect(doc.xpath("//xmlns:url").size).to eq(1001)
      expect(doc.xpath("//xmlns:loc").last.text).to eq("https://commons.stage.datacite.org/doi.org/10.70122/fk2/hlrkok")
    end
  end
end
