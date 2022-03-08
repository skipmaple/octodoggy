# frozen_string_literal: true

require_relative "octodoggy/version"
require "octodoggy/metrics/null_metric"
require "octodoggy/metrics/prometheus"
require "octodoggy/metrics"
require "octodoggy/github/client"

module Octodoggy
  class Error < StandardError; end

  class JiMao
    def initialize(token)
      @client = Octodoggy::Github::Client.new(token)
      @client.octokit.auto_paginate = true
    end

    def find_repo(repo_path)
      @client.repository(repo_path)
    rescue StandardError
      nil
    end

    def find_repos(file_path)
      content = File.read(file_path)
      urls = JSON.parse(content)
      # urls = urls.first(100)
      repo_paths = urls.each_with_object([]) { |url, r| r << url.split("/mirrors/").last.gsub(".git", "") }
      res = {}
      repo_paths.each_with_index do |repo_path, i|
        repo = find_repo(repo_path)
        print "#{i}: "
        if repo.nil?
          print "F"
        else
          print "."
        end
        next unless repo

        star_count = repo.stargazers_count
        github_forks_count = repo.forks_count
        description = repo.description
        res[repo_path] = { description: description, star_count: star_count, github_forks_count: github_forks_count }
      end

      res
    end

    def get_repos_info(input_file_path, output_file_path)
      res = find_repos(input_file_path)
      res = res.to_json
      File.open(output_file_path, "w") do |f|
        f.write(res)
      end
    end
  end

  class ErHa < JiMao
    def initialize(tokens)
      @clients = []
      tokens.each do |token|
        client = Octodoggy::Github::Client.new(token)
        client.octokit.auto_paginate = true
        @clients << client
      end
    end

    def find_repo(repo_path)
      @clients.sample.repository(repo_path)
    rescue StandardError
      nil
    end
  end
end
