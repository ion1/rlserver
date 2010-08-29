# Copyright © 2010 Johan Kiviniemi
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

require 'securerandom'
require 'thread'

class Password
  SALT_SET = ['a'..'z', 'A'..'Z', '0'..'9', %w{ . / }].map(&:to_a).flatten
  SALT_SET.freeze
  if SALT_SET.length != 64
    raise RuntimeError, "SALT_SET.length = #{SALT_SET.length}, expected 64"
  end

  def self.random_salt
    length = 9 + RANDOM.get_number(3)  # Up to 9+(2³−1)=16
    (0...length).map { SALT_SET[RANDOM.get_number(6)] }.join
  end

  def self.new_from_password password
    new password.crypt('$6$%s$' % random_salt)
  end

  def initialize encrypted
    @salt, @encrypted = encrypted.scan(/\A(\$[^$]+\$[^$]+\$)(.+)\z/).first
    if @salt.nil? or @encrypted.nil?
      raise ArgumentError, "Failed to parse #{encrypted.inspect}"
    end
  end

  def == password
    to_s == password.crypt(@salt)
  end

  def to_s
    "#{@salt}#{@encrypted}"
  end

  def inspect
    "#<#{self.class}: #{to_s.inspect}>"
  end
end

class Password
  class Random
    def initialize
      @mutex = Mutex.new
      @pool = 0
      @pool_size = 0
    end

    # 0 ≤ return_value < 2^size_bits
    def get_number size_bits
      @mutex.synchronize do
        while @pool_size < size_bits
          SecureRandom.random_bytes(32).unpack('C*').each do |byte|
            @pool = (@pool << 8) | byte
            @pool_size += 8
          end
        end

        @pool_size -= size_bits
        bits   = @pool >> @pool_size
        @pool ^= bits << @pool_size

        bits
      end
    end
  end

  RANDOM = Random.new
end

# vim:set et sw=2 sts=2:
