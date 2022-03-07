# frozen_string_literal: true

require_relative "octodoggy/version"
require "octodoggy/metrics/null_metric"
require "octodoggy/metrics/prometheus"
require "octodoggy/metrics"
require "octodoggy/github/client"

module Octodoggy

  class Error < StandardError; end

  class JiMao
    def initialize(token, full_path)
      @client = Octodoggy::Github::Client.new(token)
      @client.octokit.auto_paginate = true
      @repo_full_path = full_path
    end

    def find_repo
      @client.repository(@repo_full_path) rescue nil
    end
  end

end
