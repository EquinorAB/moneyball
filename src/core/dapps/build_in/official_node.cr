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

module ::Axentro::Core::DApps::BuildIn
  class OfficialNode < DApp
    def setup
    end

    def transaction_actions : Array(String)
      ["create_official_node_slow", "create_official_node_fast"]
    end

    def transaction_related?(action : String) : Bool
      transaction_actions.includes?(action)
    end

    def valid_transactions?(transactions : Array(Transaction)) : ValidatedTransactions
      ValidatedTransactions.with(
        transactions.select { |t| transaction_actions.includes?(t.action) },
        "Creation of official nodes is not currently permitted. Future changes will enable this.",
        transactions.reject { |t| transaction_actions.includes?(t.action) }
      )
    end

    def record(chain : Blockchain::Chain)
    end

    def clear
    end

    def define_rpc?(call, json, context, params) : HTTP::Server::Context?
      nil
    end

    def all_impl : Array(String)
      database.get_official_nodes.values.flatten.uniq!
    end

    def all_slow_impl : Array(String)
      database.get_official_nodes["slownodes"].uniq
    end

    def all_fast_impl : Array(String)
      database.get_official_nodes["fastnodes"].uniq
    end

    def i_am_a_fastnode?(address : String) : Bool
      all_fast_impl.includes?(address)
    en