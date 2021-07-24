# Copyright © 2017-2020 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

module ::Axentro::Core
  class DeveloperFund
    @config : DeveloperFundConfig

    def self.validate(path : String | Nil)
      path.nil? ? nil : self.new(path)
    end

    def initialize(@path : String)
      @config = validate(path)
    end

    def get_config
      @config
    end

    def set_config(config)
      @config = config
    end

    def get_path
      @path.nil? ? "unknown" : @path
    end

    def get_total_amount : Int64
      @config.addresses.reduce(0_i64) { |total, item| total + scale_i64(item["amount"]) }
    end

    def self.transactions(config : DeveloperFundCon