require 'logstash-logger'
require 'retriable'
require 'slack-notifier'

module Maltese
  class ::InternalServerError < StandardError; end
  class ::BadGatewayError < StandardError; end

  class Datafile

  end
end
