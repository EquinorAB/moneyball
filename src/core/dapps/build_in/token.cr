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
        raise "must not be the default token: #{token}" if token == TOKEN_DEFAULT
        raise "senders can only be 1 for token action" if transaction.senders.size != 1
        raise "number of specified senders must be 1 for '#{action}'" if transaction.senders.size != 1
        raise "number of specified recipients must be 1 for '#{action}'" if transaction.recipients.size != 1

        sender = transaction.senders[0]
        sender_address = sender.address
        sender_amount = sender.amount

        recipient = transaction.recipients[0]
        recipient_address = recipient.address
        recipient_amount = recipient.amount

        raise "address mismatch for '#{action}'. " +
              "sender: #{sender_address}, recipient: #{recipient_address}" if sender_address != recipient_address

        raise "amount mismatch for '#{action}'. " +
              "sender: #{sender_amount}, recipient: #{recipient_amount}" if sender_amount != recipient_amount

        raise "invalid token name: #{token}" unless valid_token_name?(token)

        if ["create_token", "update_token", "burn_token"].includes?(action)
          raise "invalid quantity: #{recipient_amount}, must be a positive number greater than 0" unless recipient_amount > 0_i64
        end

        # rules for create token
        token_exists_in_db = !token_map[token]?.nil?

        # find if the token was created within the current set of transactions
        token_exists_in_transactions = processed_transactions.find { |processed_transaction|
          processed_transaction.token == token && processed_transaction.action == "create_token"
        }

        # find if the token was locked within the current set of transactions
        token_locked_in_transactions = processed_transactions.find { |processed_transaction|
          processed_transaction.token == token && processed_transaction.action == "lock_token"
        }

        if action == "create_token"
          raise "the token #{token} is already created" if token_exists_in_db

          processed_transactions.each do |processed_transaction|
            raise "the token #{token} is already created" if processed_transaction.token == token
          end
        end

        # rules for just update
        if action == "update_token"
          if (token_exists_in_db && token_map[token].is_locked) || !token_locked_in_transactions.nil?
            raise "the token: #{token} is locked and may no longer