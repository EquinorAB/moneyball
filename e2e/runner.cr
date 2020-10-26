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

    def create_official_nodes(wallet_addresses : Array(String))
      fastnodes = [wallet_addresses.first]
      slownodes = wallet_addresses

      official_nodes_string = {
        "fastnodes" => fastnodes,
        "slownodes" => slownodes,
      }.to_yaml

      File.open(official_nodes_file, "w") { |f| f.puts official_nodes_string }
    end

    def launch_node(node_port, is_private, connecting_port, idx, db)
      node(node_port, is_private, connecting_port, idx, db)
      @node_ports_public.push(node_port) unless is_private
    end

    def launch_first_node
      launch_node(@node_ports[0], false, nil, 0, "0_node_" + @db_name)
    end

    def launch_nodes
      step launch_first_node, 5, "launch first node"

      @node_ports[1..-1].each_with_index do |node_port, idx|
        is_private = case @mode
                     when E2E::ALL_PUBLIC
                       false
                     when E2E::ALL_PRIVATE
                       true
                     when E2E::ONE_PRIVATE
                       idx == 0
                     else
                       false
                     end

        connecting_port = @node_ports_public.sample

        step launch_node(node_port, is_private, connecting_port, idx + 1, (idx + 1).to_s + "_node_" + @db_name), 5,
          "launch node on port #{node_port} connect to #{connecting_port} #{is_private ? "(private)" : "(public)"}"
      end
    end

    def kill_nodes
      `pkill -f axen`
    end

    def launch_miners
      if @num_miners != @node_ports.size
        @num_miners.times do |_|
          port = @node_ports.sample
          step mining(port, Random.rand(@num_miners)), 1, "launch miner for #{port}"
        end
      else
        @num_miners.times do |t|
          port = @node_ports[t]
          step mining(port, t), 1, "launch miner for #{port}"
        end
      end
    end

    def kill_miners
      `pkill -f axem`
    end

    def launch_client
      Client.launch
    end

    def kill_client
      Client.finish

      if response = Client.receive
        result = Client::Result.from_json(response)

        @num_transactions = result.num_transactions
        @duration = result.duration
      end
    end

    def block_sizes : Array(NamedTuple(port: Int32, size: Int32))
      @node_ports.map { |port| {port: port, size: blockchain_size(port)} }
    end

    def latest_block_index : Int32
  