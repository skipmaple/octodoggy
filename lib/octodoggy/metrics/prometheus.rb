# frozen_string_literal: true

require "active_support"
require "prometheus/client"

module Octodoggy
  module Metrics

    module Prometheus
      extend ActiveSupport::Concern

      REGISTRY_MUTEX = Mutex.new
      PROVIDER_MUTEX = Mutex.new

      class_methods do

        def metrics_folder_present?
          multiprocess_files_dir = ::Prometheus::Client.configuration.multiprocess_files_dir

          multiprocess_files_dir &&
            ::Dir.exist?(multiprocess_files_dir) &&
            ::File.writable?(multiprocess_files_dir)
        end

        def prometheus_metrics_enabled?
          prometheus_metrics_enabled_unmemoized
        end

        def reset_registry!
          clear_memoization(:registry)

          REGISTRY_MUTEX.synchronize do
            ::Prometheus::Client.reset!
          end
        end

        def registry
          REGISTRY_MUTEX.synchronize do
            ::Prometheus::Client.registry
          end
        end

        def counter(name, docstring, base_labels = {})
          safe_provide_metric(:counter, name, docstring, base_labels)
        end

        def summary(name, docstring, base_labels = {})
          safe_provide_metric(:summary, name, docstring, base_labels)
        end

        def gauge(name, docstring, base_labels = {}, multiprocess_mode = :all)
          safe_provide_metric(:gauge, name, docstring, base_labels, multiprocess_mode)
        end

        def histogram(name, docstring, base_labels = {}, buckets = ::Prometheus::Client::Histogram::DEFAULT_BUCKETS)
          safe_provide_metric(:histogram, name, docstring, base_labels, buckets)
        end

        def error_detected!
          set_error!(true)
        end

        def clear_errors!
          set_error!(false)
        end

        def set_error!(status)
          clear_memoization(:prometheus_metrics_enabled)

          PROVIDER_MUTEX.synchronize do
            @error = status
          end
        end

        private

        def safe_provide_metric(method, name, *args)
          metric = provide_metric(name)
          return metric if metric

          PROVIDER_MUTEX.synchronize do
            provide_metric(name) || registry.method(method).call(name, *args)
          end
        end

        def provide_metric(name)
          if prometheus_metrics_enabled?
            registry.get(name)
          else
            NullMetric.instance
          end
        end

        def prometheus_metrics_enabled_unmemoized
          !error? && metrics_folder_present? || false
        end
      end
    end
  end
end
