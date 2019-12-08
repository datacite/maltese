require 'spec_helper'

describe Maltese::Sitemap, vcr: true do
  subject { Maltese::Sitemap.new }

  let(:doi) { "10.1097/npt.0b013e3181c1fc0b" }

  context "get_query_url" do
    it "default" do
      expect(subject.get_query_url).to eq("https://api.test.datacite.org/dois?fields%5Bdois%5D=doi%2Cupdated&page%5Bscroll%5D=3m&page%5Bsize%5D=1000")
    end

    it "with page[size] one" do
      expect(subject.get_query_url(size: 1)).to eq("https://api.test.datacite.org/dois?fields%5Bdois%5D=doi%2Cupdated&page%5Bscroll%5D=3m&page%5Bsize%5D=1")
    end

    it "with size" do
      expect(subject.get_query_url(size: 250)).to eq("https://api.test.datacite.org/dois?fields%5Bdois%5D=doi%2Cupdated&page%5Bscroll%5D=3m&page%5Bsize%5D=250")
    end
  end

  context "get_total" do
    it "with works" do
      expect(subject.get_total).to eq(807468)
    end
  end

  context "queue_jobs" do
    it "should report if there are works returned by the Datacite REST API" do
      response = subject.queue_jobs
      expect(response).to eq(807880)
    end
  end

  context "get_data" do
    it "should report if there are works returned by the Datacite REST API" do
      response = subject.get_data(subject.get_query_url)
      expect(response.body.dig("meta", "total")).to eq(806854)
      expect(response.body.fetch("data", []).size).to eq(1000)
      doc = response.body.fetch("data", []).first
      expect(doc.dig("attributes", "doi")).to eq(doi)
    end

    it "should catch errors with the Datacite REST API" do
      stub = stub_request(:get, subject.get_query_url).to_return(:status => [408])
      response = subject.get_data(subject.get_query_url)
      expect(response.body).to eq("errors"=>[{"status"=>408, "title"=>"Request timeout"}])
      expect(stub).to have_been_requested
    end
  end

  context "parse_data" do
    it "should report if there are no works returned by the Datacite REST API" do
      body = File.read(fixture_path + 'sitemap_nil.json')
      result = OpenStruct.new(body: JSON.parse(body))
      expect(subject.parse_data(result)).to eq(0)
    end

    it "should report if there are works returned by the Datacite REST API" do
      body = File.read(fixture_path + 'sitemap.json')
      result = OpenStruct.new(body: JSON.parse(body))
      response = subject.parse_data(result)
      expect(response).to eq(1001)
    end

    it "should catch timeout errors with the Datacite REST API" do
      result = OpenStruct.new(body: { "errors" => [{ "title" => "the server responded with status 408 for https://REST.test.datacite.org", "status" => 408 }] })
      response = subject.parse_data(result)
      expect(response).to eq(result.body["errors"])
    end
  end

  context "push_data" do
    it "should report if there are no works returned by the Datacite REST API" do
      result = []
      expect { subject.push_data }.to output(/1 links/).to_stdout
    end

    it "should report if there are works returned by the Datacite REST API" do
      body = File.read(fixture_path + 'sitemap.json')
      result = OpenStruct.new(body: JSON.parse(body))
      result = subject.parse_data(result)
      expect { subject.push_data }.to output(/1001 links/).to_stdout
    end
  end
end
