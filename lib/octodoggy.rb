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

  class BianMu < ErHa
    def find_repo(client, repo_path)
      client.repository(repo_path)
    rescue StandardError
      nil
    end

    def get_repos_info(input_file_path, output_file_path)
      res = {}
      index = 0
      clients_size = @clients.size

      json_content = File.read(output_file_path) rescue nil
      current_res = JSON.parse(json_content)
      ready_repo_paths = current_res.keys

      File.readlines(input_file_path).each_slice(clients_size) do |lines|
        index += clients_size
        print "\n#{index - clients_size} - #{index} \n"

        threads = []
        lines.each_with_index do |line, i|
          repo_path = line.strip.gsub("mirrors/", "")
          next if ready_repo_paths.include?(repo_path)

          threads << Thread.new do
            repo = find_repo(@clients[i], repo_path)
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
          threads.map(&:join)
        end

        print("\nres_size: #{res.size}\n")
        next unless res.size >= 100

        json = File.read(output_file_path) rescue nil
        File.open(output_file_path, "w") do |f|
          f.puts JSON.pretty_generate(json.nil? || json.empty? ? res : JSON.parse(json)&.merge(res))
          res = {}
        end
      end

      if res.size > 0
        json = File.read(output_file_path) rescue nil
        File.open(output_file_path, "w") do |f|
          f.puts JSON.pretty_generate(json.nil? || json.empty? ? res : JSON.parse(json)&.merge(res))
          res = {}
        end
      end

      # tokens = %w[token1 token2 token3]
      #
      # Octodoggy::BianMu.new(tokens).get_repos_info("/Users/maple/work/personal_work/octodoggy/projects.txt", "/Users/maple/work/personal_work/octodoggy/res.json")
      #
      # group = Group.find_by_name("mirrors")
      # current_user = User.first
      # projects = GroupProjectsFinder.new(group: group, current_user: current_user, options: { include_subgroups: true }).execute
      #
      # origin_path = "/etc/gitlab/res.json"
      # c = File.read(origin_path)
      # big_h = JSON.parse(c)
      #
      # big_h_keys = big_h.keys
      # projects.each_with_index do |p, i|
      #   repo_path = p.full_path.gsub("mirrors/", '')
      #   if big_h_keys.include?(repo_path)
      #     h = big_h[repo_path]
      #     Project.where(id: p.id).update_all(
      #       :star_count => h['star_count'],
      #       :github_forks_count => h['github_forks_count'],
      #       :description => h['description']
      #     )
      #     puts("#{i} #{repo_path}")
      #   end
      # end

    end

  end
end
