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
module FunctionalHelper
  include Axentro::Core
  include Axentro::Common::Denomination

  class Quantity
    def self.as_internal_amount(variable_name : String, variables) : Int64
      scale_i64(variables[variable_name]["value"])
    end

    def self.as_internal_amount(value : String) : Int64
      scale_i64(value)
    end

    def self.as_fund_amount(variable_name : String, variables) : String
      scale_i64(scale_decimal(variables[variable_name]["value"].to_i64)).to_s
    end

    def self.as_human_amount(amount : Int64) : String
      scale_decimal(amount)
    end
  end

  c