require 'logger'

module RLServer
  client = ENV['SSH_CLIENT']
  @log = Logger.new("#{client}.log", 'daily')
  @log.datetime_format = '%Y-%m-%d %H:%M:%S'
  @log.sev_threshold = case ENV['RL_LOG_SEVERITY']
                       when 'DEBUG'
                         Logger::DEBUG
                       when 'INFO'
                         Logger::INFO
                       when 'WARN'
                         Logger::WARN
                       when 'ERROR'
                         Logger::ERROR
                       when 'FATAL'
                         Logger::FATAL
                       when 'UNKNOWN'
                         Logger::UNKNOWN
                       else
                         Logger::ERROR
                       end
  def self.log
    @log
  end
end
