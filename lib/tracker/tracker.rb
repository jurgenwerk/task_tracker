require 'uri'
require 'net/http'
require 'net/https'
require 'json'
require 'logger'
require 'pry'

class Tracker
  TRACK_URL = "http://localhost:3000/api/v1"
  TASK_START_URL = TRACK_URL + "/task_instances/start"
  TASK_END_URL = TRACK_URL + "/task_instances/end"

  def initialize(task_name, config: {})
    set_config(config)
    @task_name = task_name
  end

  def self.track(task_name, config)
    task_tracker = self.new(task_name, config)
    task_tracker.task_start
    yield
    task_tracker.task_end
  end

  def task_start
    @task_instance_uuid = SecureRandom.uuid
    @start_time = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S.%N')
    params = {
      task_name: @task_name,
      start_time: @start_time.to_s,
      task_instance_uuid: @task_instance_uuid
    }

    make_request(:start, params)
  end

  def task_end
    if @task_instance_uuid.nil?
      TaskTracker.logger.error "You have to start a task before you can end it."
      return
    end

    @end_time = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S.%N')
    params = {
      task_instance_uuid: @task_instance_uuid,
      end_time: @end_time.to_s
    }

    resp = make_request(:end, params)
    reset! if resp.code.to_i == 200
    resp
  end

  private
  def make_request(status, params)
    url =
      if status == :start
        TASK_START_URL
      else
        TASK_END_URL
      end

    uri = URI(url)
    https = Net::HTTP.new(uri.host, uri.port)
    https.open_timeout = 30
    https.read_timeout = 30

    params = params.merge(monitor_api_key: @monitor_api_key)
    req = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json; charset=UTF-8')
    https.request(req, params.to_json)
  rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
    Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
    TaskTracker.logger.error("Failed HTTP request: #{e.message}. Retrying...")
  end

  def reset!
    @start_time = nil
    @end_time = nil
    @task_instance_uuid = nil
  end

  def set_config(config)
    @monitor_api_key =
      if config && config[:MONITOR_API_KEY]
        config[:MONITOR_API_KEY]
      elsif
        ENV["MONITOR_API_KEY"]
      end

    unless @monitor_api_key
      TaskTracker.logger.error
        "No MONITOR_API_KEY was found in ENV or in config passed into `Tracker.new`"
    end
  end
end
