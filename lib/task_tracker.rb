require "task_tracker/version"
require "tracker/tracker"

module TaskTracker
  class << self
    attr_writer :logger

    def logger
      @logger ||= Logger.new($stdout).tap do |log|
        log.progname = self.name
      end
    end
  end

  module_function

  def track
    measurements =
      Benchmark.measure do
        yield
      end

    real_time_elapsed = measurements.real
    # track this somewhere
  end
end
