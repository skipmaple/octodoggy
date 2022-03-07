# frozen_string_literal: true

require "singleton"

module Octodoggy
  module Metrics
    # Mocks ::Prometheus::Client::Metric and all derived metrics
    class NullMetric
      include Singleton

      def method_missing(name, *args, &block)
        nil
      end
    end
  end
end
