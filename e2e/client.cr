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
require "./utils"

module ::E2E
  class Client < Tokoroten::Worker
    @@client : Tokoroten::Worker? = nil
    @@no_transactions : Bool = false

    alias ClientWork = NamedTuple(call: Int32, content: String)

    struct Initialize
      include JSON::Serializable
      property node_ports : Array(Int32)
      property num_miners : Int32
      property num_tps : Int32
      property pct_fast_txns : Int32
    end

    struct Result
      include JSON::Serializable
      property num_transactions : Int32
      property duration : Float64
    end

    def self.client
      @@client.not_nil!
    end

    def self.initialize(node_ports : Array(Int32), num_miners : Int32, no_transactions : Bool, num_tps : Int32, pct_fast_txns : Int32)
      @@client = Client.create(1)[0]
      @@no_transactions = no_transactions

      puts "Transactions Per Second goal: #{num_tps}"
      puts "(as many as possible)" if num_tps == 0

      puts "Fast transaction percentage: #{pct_fast_txns}"

      request = {call: 0, content: {node_ports: node_ports, num_miners: num_mi