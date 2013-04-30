require 'rake'
require 'github_api'

class TddiumStatusGithub
  def url
    "https://api.tddium.com/1/reports/#{session}"
  end

  def sha
    `git rev-parse HEAD`.strip
  end

  def session
    ENV['TDDIUM_SESSION_ID']
  end

  def token
    ENV['GITHUB_TOKEN']
  end

  def github
    @github ||= Github.new(:oauth_token => token)
  end

  def remote
    url = `git config --get remote.ci-origin.url`.strip
    url =~ /.*[:\/](.*\/[^\.]*)/ && $1.split("/")
  end
end

namespace :tddium do
  task :setup do
    @tdd = TddiumStatusGithub.new
  end

  desc "tddium environment pre-run setup task"
  task :pre_hook => :setup do
    if @tdd.token && !@tdd.token.empty?
      begin
        @tdd.github.repos.statuses.create(@tdd.remote[0], @tdd.remote[1], @tdd.sha,
          :state => "pending",
          :description => "Running build ##{@tdd.session}.",
          :target_url => @tdd.url)
      rescue Github::Error::GithubError => e
        STDERR.puts("Caught Github error when updating status: #{e.message}")
      end
    end
  end

  desc "tddium environment post-build setup task"
  task :post_build_hook => :setup do
    if @tdd.token && !@tdd.token.empty?
      case ENV['TDDIUM_BUILD_STATUS']
      when "passed"
        status = "success"
        description = "Build ##{@tdd.session} succeeded!"
      when "error"
        status = "error"
        description = "Build ##{@tdd.session} encountered an error."
      else
        status = "failure"
        description = "Build ##{@tdd.session} failed."
      end

      begin
        @tdd.github.repos.statuses.create(@tdd.remote[0], @tdd.remote[1], @tdd.sha,
          :state => status,
          :description => description,
          :target_url => @tdd.url)
      rescue Github::Error::GithubError => e
        STDERR.puts("Caught Github error when updating status: #{e.message}")
      end
    end
  end
end
