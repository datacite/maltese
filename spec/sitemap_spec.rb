require 'spec_helper'

describe Maltese::Sitemap, vcr: true do
  subject { Maltese::Sitemap.new(rack_env: "test") }

  let(:doi) { "10.25601/2f56-s909" }

  context "get_query_url" do
    it "default" do
      expect(subject.get_query_url).to eq("https://api.stage.datacite.org/dois?fields%5Bdois%5D=doi%2Cupdated&exclude-registration-agencies=true&page%5Bscroll%5D=7m&page%5Bsize%5D=1000")
    end

    it "with page[size] one" do
      expect(subject.get_query_url(size: 1)).to eq("https://api.stage.datacite.org/dois?fields%5Bdois%5D=doi%2Cupdated&exclude-registration-agencies=true&page%5Bscroll%5D=7m&page%5Bsize%5D=1")
    end

    it "with size" do
      expect(subject.get_query_url(size: 250)).to eq("https://api.stage.datacite.org/dois?fields%5Bdois%5D=doi%2Cupdated&exclude-registration-agencies=true&page%5Bscroll%5D=7m&page%5Bsize%5D=250")
    end
  end

  context "get_total" do
    it "with works" do
      expect(subject.get_total).to eq(207479)
    end
  end

  context "queue_jobs" do
    it "should report if there are works returned by the Datacite REST API" do
      response = subject.queue_jobs
      expect(response).to eq(207479)
    end
  end

  context "process_data" do
    it "should handle timeout errors with the Datacite REST API" do
      stub = stub_request(:get, subject.get_query_url).and_return({ status: [408] }, { status: [408] }, { status: [200] })
      response = subject.process_data(total: 10, url: subject.get_query_url)
      expect(response).to eq(1)
    end

    it "should handle bad request errors with the Datacite REST API" do
      stub = stub_request(:get, subject.get_query_url).and_return({ status: [502] }, { status: [200] })
      response = subject.process_data(total: 10, url: subject.get_query_url)
      expect(response).to eq(1)
    end

    it "should retry 2 times for bad request errors with the Datacite REST API" do
      stub = stub_request(:get, subject.get_query_url).and_return({ status: [502] }, { status: [502] }, { status: [502] })
      response = subject.process_data(total: 10, url: subject.get_query_url)
      expect(response).to eq(1)
    end

    it "should handle internal server errors with the Datacite REST API" do
      stub = stub_request(:get, subject.get_query_url).and_return({ status: [500] }, { status: [200] })
      response = subject.process_data(total: 10, url: subject.get_query_url)
      expect(response).to eq(1)
    end
  end

  context "get_data" do
    it "should report if there are works returned by the Datacite REST API" do
      response = subject.get_data(subject.get_query_url)
      expect(response.body.dig("meta", "total")).to eq(207479)
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

  context "send_notification_to_slack" do
    it "send info" do
      fields = [
        { title: "URL", value: "https://commons.stage.datacite.org/sitemaps/sitemap.xml.gz" },
        { title: "Number of DOIs", value: 271605.to_s(:delimited), short: true },
        { title: "Number of Sitemaps", value: 6.to_s(:delimited), short: true },
        { title: "Time Taken", value: "33 min", short: true }
      ]
      expect(subject.send_notification_to_slack(nil, title: subject.slack_title + ": Sitemaps Updated", level: "good", fields: fields)).to eq("ok")
    end

    it "send error" do
      fields = [
        { title: "Error", value: "Error: A bad gateway error occured for URL https://api.datacite.org/dois?page%5Bscroll%5D=7m&page%5Bsize%5D=1000&scroll-id=DnF1ZXJ5VGhlbkZldGNoBQAAAAACJPb5FjI5NUhiM3dqU0JleHRSWlJGTnhYaXcAAAAAAiT2-hYyOTVIYjN3alNCZXh0UlpSRk54WGl3AAAAAAIk9vsWMjk1SGIzd2pTQmV4dFJaUkZOeFhpdwAAAAACJPb8FjI5NUhiM3dqU0JleHRSWlJGTnhYaXcAAAAAAiT2_RYyOTVIYjN3alNCZXh0UlpSRk54WGl3." },
        { title: "Number of DOIs", value: 141572.to_s(:delimited), short: true },
        { title: "Number of Sitemaps", value: 3.to_s(:delimited), short: true },
        { title: "Time Taken", value: "17 min", short: true }
      ]
      expect(subject.send_notification_to_slack(nil, title: subject.slack_title + ": Sitemaps Not Updated", level: "danger", fields: fields)).to eq("ok")
    end
  end
end
