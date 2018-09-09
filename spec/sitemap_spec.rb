require 'spec_helper'

describe Maltese::Sitemap, vcr: true do
  subject { Maltese::Sitemap.new }

  let(:total) { 10 }
  let(:doi) { "10.15771/IMEJIDEV.RM" }
  let(:from_date) { (Date.current - 1.day).strftime("%F") }
  let(:until_date) { Date.current.strftime("%F") }

  context "get_query_url" do
    it "default" do
      expect(subject.get_query_url).to eq("https://solr.test.datacite.org/api?q=*%3A*&fq=updated%3A%5B#{from_date}T00%3A00%3A00Z+TO+#{until_date}T23%3A59%3A59Z%5D+AND+has_metadata%3Atrue+AND+is_active%3Atrue&start=0&rows=50000&fl=doi%2Cupdated&sort=updated+asc&wt=json")
    end

    it "with zero rows" do
      expect(subject.get_query_url(rows: 0)).to eq("https://solr.test.datacite.org/api?q=*%3A*&fq=updated%3A%5B#{from_date}T00%3A00%3A00Z+TO+#{until_date}T23%3A59%3A59Z%5D+AND+has_metadata%3Atrue+AND+is_active%3Atrue&start=0&rows=0&fl=doi%2Cupdated&sort=updated+asc&wt=json")
    end

    it "with different from_date and until_date" do
      subject = Maltese::Sitemap.new(from_date: "2015-04-05", until_date: "2015-04-05")
      expect(subject.get_query_url).to eq("https://solr.test.datacite.org/api?q=*%3A*&fq=updated%3A%5B2015-04-05T00%3A00%3A00Z+TO+2015-04-05T23%3A59%3A59Z%5D+AND+has_metadata%3Atrue+AND+is_active%3Atrue&start=0&rows=50000&fl=doi%2Cupdated&sort=updated+asc&wt=json")
    end

    it "with offset" do
      expect(subject.get_query_url(offset: 250)).to eq("https://solr.test.datacite.org/api?q=*%3A*&fq=updated%3A%5B#{from_date}T00%3A00%3A00Z+TO+#{until_date}T23%3A59%3A59Z%5D+AND+has_metadata%3Atrue+AND+is_active%3Atrue&start=250&rows=50000&fl=doi%2Cupdated&sort=updated+asc&wt=json")
    end

    it "with rows" do
      expect(subject.get_query_url(rows: 250)).to eq("https://solr.test.datacite.org/api?q=*%3A*&fq=updated%3A%5B#{from_date}T00%3A00%3A00Z+TO+#{until_date}T23%3A59%3A59Z%5D+AND+has_metadata%3Atrue+AND+is_active%3Atrue&start=0&rows=250&fl=doi%2Cupdated&sort=updated+asc&wt=json")
    end
  end

  context "get_total" do
    it "with works" do
      expect(subject.get_total).to eq(total)
    end

    it "with no works" do
      subject = Maltese::Sitemap.new(from_date: "2005-04-07", until_date: "2005-04-08")
      expect(subject.get_total).to eq(0)
    end
  end

  context "queue_jobs" do
    it "should report if there are no works returned by the Datacite Solr API" do
      subject = Maltese::Sitemap.new(from_date: "2005-04-07", until_date: "2005-04-08")
      response = subject.queue_jobs
      expect(response).to eq(0)
    end

    it "should report if there are works returned by the Datacite Solr API" do
      response = subject.queue_jobs
      expect(response).to eq(total)
    end
  end

  context "get_data" do
    it "should report if there are no works returned by the Datacite Solr API" do
      subject = Maltese::Sitemap.new(from_date: "2005-04-07", until_date: "2005-04-08")
      response = subject.get_data
      expect(response.body.dig("data", "response", "numFound")).to eq(0)
    end

    it "should report if there are works returned by the Datacite Solr API" do
      response = subject.get_data
      expect(response.body.dig("data", "response", "numFound")).to eq(total)
      doc = response.body.dig("data", "response", "docs").first
      expect(doc["doi"]).to eq(doi)
    end

    it "should catch errors with the Datacite Solr API" do
      stub = stub_request(:get, subject.get_query_url(rows: 0)).to_return(:status => [408])
      response = subject.get_data(rows: 0)
      expect(response.body).to eq("errors"=>[{"status"=>408, "title"=>"Request timeout"}])
      expect(stub).to have_been_requested
    end
  end

  context "parse_data" do
    it "should report if there are no works returned by the Datacite Solr API" do
      body = File.read(fixture_path + 'sitemap_nil.json')
      result = OpenStruct.new(body: { "data" => JSON.parse(body) })
      expect(subject.parse_data(result)).to eq(0)
    end

    it "should report if there are works returned by the Datacite Solr API" do
      body = File.read(fixture_path + 'sitemap.json')
      result = OpenStruct.new(body: { "data" => JSON.parse(body) })
      response = subject.parse_data(result)
      expect(response).to eq(2522)
    end

    it "should catch timeout errors with the Datacite Solr API" do
      result = OpenStruct.new(body: { "errors" => [{ "title" => "the server responded with status 408 for https://solr.test.datacite.org", "status" => 408 }] })
      response = subject.parse_data(result)
      expect(response).to eq(result.body["errors"])
    end
  end

  context "push_data" do
    it "should report if there are no works returned by the Datacite Solr API" do
      result = []
      expect { subject.push_data }.to output(/1 links/).to_stdout
    end

    it "should report if there are works returned by the Datacite Solr API" do
      body = File.read(fixture_path + 'sitemap.json')
      result = OpenStruct.new(body: { "data" => JSON.parse(body) })
      result = subject.parse_data(result)
      expect { subject.push_data }.to output(/2522 links/).to_stdout
    end
  end
end
