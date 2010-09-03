# Roguelike server in the spirit of dgamelaunch
#
# Copyright © 2010 Joosa Riekkinen
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

$LOAD_PATH << File.join(File.dirname(__FILE__), 'lib')

require 'fileutils'

require 'log'

module RLServer
  module Config
    RL_CONFIG = "/etc/rlserver"
    def self.config;@config end

    def self.load_config_file(file)
      config = {}
      RLServer.log.info "Config file: #{file}"
      File.foreach file do |line|
        unless line[/^#/] then
          key, value = line.split "=", 2
          if key and value then
            config[key.strip] = value.strip.gsub /\\n/, "\n"
          end
        end
      end
      config
    end

    def self.load_config_dir(dir)
      config = {}
      path = File.expand_path(dir) + "/"
      RLServer.log.info "Config directory: #{path}"
      Dir.foreach path do |file|
        if File.directory? path + file then
          if file != ".." and file != "." then
            config[file] = load_config_dir path + file
          end
        else
          config[file] = load_config_file path + file
        end
      end
      config
    end

    def self.load
      @config = load_config_dir RL_CONFIG
    end
  end
end
