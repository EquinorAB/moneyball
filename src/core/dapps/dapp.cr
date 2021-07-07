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

module ::Axentro::Core::DApps
  ASSET_ACTIONS    = ["create_asset", "update_asset", "send_asset"]
  UTXO_ACTIONS     = ["head", "send", "hra_buy", "hra_sell", "hra_cancel", "create_token", "update_token", "lock_token", "burn_token"]
  INTERNAL_ACTIONS = UTXO_ACTIONS + ASSET_ACTIONS

  abstract class DApp
    extend Common::Denomination

    abstract def setup
    abstract def transaction_actions : Array(String)
    abstract def transaction_related?(action : String) : Bool
    abstract def valid_transactions?(transactions : Array(Transaction)) : ValidatedTransactions
    abstract def record(chain : Blockchain::Chain)
    abstract def clear
    abstract def define_rpc?(
      call : String,
      json : JSON::Any,
      context : HTTP::Server::Context,
      params : Hash(String, String)
    ) : HTTP::Server::Context?
    abstract def on_message(
      action : String,
      from_address : String,
      content : String,
      from : NodeComponents::Chord::NodeContext? = nil
    ) : Bool

    def initialize(@blockchain : Blockchain)
    end

    def valid?(transactions : Array(Transaction)) : ValidatedTransactions
      vt = ValidatedTransactions.empty
      # coinbase transactions should not be checked for fees
      transactions.each do |transaction| # all asset transactions are free
        vt << rule_not_enough_fee(transaction) unless transaction.is_coinbase? || ASSET_ACTIONS.includes?(transaction.action)
      end
      vt.concat(valid_transactions?(transactions))
    end

    private def rule_not_enough_fee(transaction : Transaction)
      transaction.total_fees < self.class.fee(transaction.action) ? FailedTransaction.new(transaction, "not enough fee, should be #{scale_decimal(transaction.to