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
  struct TokenInfo
    getter created_by : String
    getter is_locked : Bool

    def initialize(@created_by : String, @is_locked : Bool)
    end
  end

  class Token < DApp
    getter tokens : Array(String) = ["AXNT"]

    def setup
    end

    def transaction_actions : Array(String)
      ["create_token", "update_token", "lock_token", "burn_token"]
    end

    def transaction_related?(action : String) : Bool
      transaction_actions.includes?(action)
    end

    # split these out to reduce complexity in the future
    # ameba:disable Metrics/CyclomaticComplexity
    def valid_transactions?(transactions : Array(Transaction)) : ValidatedTransactions
      vt = ValidatedTransactions.empty
      processed_transactions = transactions.select(&.is_coinbase?)

      body_transactions = transactions.reject(&.is_coinbase?)
      token_map = database.token_info(body_transactions.map(&.token).reject(&.==(TOKEN_DEFAULT)).uniq!)

      body_transactions.each do |transaction|
        token = transaction.token
        action = transaction.action

        # common rules for token
        raise "must not be the default token: #{token}" if t