# Roguelike server in the spirit of dgamelaunch
#
# CANNOT BE ARSED PUBLIC LICENSE
# TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
# 0. You just DO WHAT THE FUCK YOU WANT TO.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

require 'logger'

module RLServer
  client = ENV['SSH_CLIENT']
  @log = Logger.new("rlserver.log", 'daily')
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
