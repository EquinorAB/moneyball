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

require "random"
require "file_utils"
require "./utils"
require "./client"
require "yaml"

module ::E2E
  ALL_PUBLIC  = 0
  ALL_PRIVATE = 1
  ONE_PRIVATE = 2

  CONFIRMATION = 3

  class Runner
    @db_name : String

    @node_ports : Array(Int32)
    @node_ports_public : Array(Int32) = [] of Int32

    @num_transactions : Int32 = 0
    @duration : Float64 = 0.0

    getter exit_code : Int32 = 0

    def initialize(@mode : Int32, @num_nodes : Int32, @num_miners : Int32, @time : Int32, @keep_logs : Bool, @no_transactions : Bool, @num_tps : Int32, @pct_fast_txns : Int32)
      @node_ports = (4001..4001 + (@num_nodes - 1)).to_a

      Client.initialize(@node_ports, @num_miners, @no_transactions, @num_tps, @pct_fast_txns)

      @db_name = Random.new.hex
    end

    def create_wallets_and_funds
      wallet_addresses = [] of String
      [@num_nodes, @num_miners].max.times do |idx|
        create_wallet(idx)
        wallet_json = File.read(wallet(idx))
        the_parsed_wallet = JSON.parse(wallet_json)
        address = the_parsed_wallet["address"]
        wallet_addresses << address.as_s
      end
      developer_fund_string = "addresses:\n"
      wallet_addresses.each do |addr|
        developer_fund_string += "  - address: #{addr}\n    amount: \"10000\"\n"
      end
      File.write(developer_fund_file, developer_fund_string, "w")
      create_official_nodes(wallet_addresses)
    end

    def create_official_nodes(wallet_addresses : Arr