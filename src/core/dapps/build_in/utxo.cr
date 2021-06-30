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
  struct TokenQuantity
    getter token : String
    getter amount : Int64

    def initialize(@token : String, @amount : Int64); end
  end

  class UTXO < DApp
    DEFAULT = "AXNT"

    def setup
    end

    def get_for_batch(address : String, token : String, historic_per_address : Hash(String, Array(TokenQuantity))) : Int64
      return 0_i64 if historic_per_address[address]?.nil?
      historic_per_address[address].select(&.token.==(token)).sum(&.amount)
    end

    def get_pending_batch(address : String, transactions : Array(Transaction), token : String, historic_per_address : Hash(String, Array(TokenQuantity))) : Int64
      historic = get_for_batch(address, token, historic_per_address)

      if token == "AXNT"
        fees_sum = transactions.flat_map(&.senders).select(&.address.==(address)).sum(&.fee)
        senders_sum = transactions.select(&.token.==(token)).flat_map(&.senders).select(&.address.==(address)).sum(&.amount)
        recipients_sum = transactions.select(&.token.==(token)).flat_map(&.recipients).select(&.address.==(address)).sum(&.amount)
        historic + (recipients_sum - (senders_sum + fees_sum))
      else
        # when tokens are created or updated the sender == recipient. This results in 0 pending amounts since the total is recipient - sender.
        # so for these cases we discard the sender amount in the calculation.
        exclusions = ["create_token", "update_token"]
        senders_sum = transactions.reject { |t| exclusions.includes?(t.action) }.select(&.token.==(token)).flat_map(&.senders).select(&.address.==(address)).sum(&.amount)
        recipients_sum = transactions.select(&.token.==(token)).flat_map(&.recipients).select(&.address.==(address)).sum(&.amount)
        historic + (recipients_sum - (senders_sum))
      end
    end

    def transaction_actions : Array(String)
      ["send"]
    end

    def transaction_related?(action : String) : Bool
      UTXO_ACTIONS.includes?(action)
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def valid_transactions?(transactions : Array(Transaction)) : ValidatedTransactions
      # get amounts for all addresses into an in memory structure for all relevant tokens
      addresses = transactions.flat_map { |t| t.senders.map(&.address) }
      historic_per_address = database.get_address_amounts(addresses)
      vt = ValidatedTransactions.empty

      # add coinbase here as needed for the amount calculations used in get_pending
      processed_transactions = transactions.select(&.is_coinbase?)

      # remove coinbases as not required for validation here
      transactions.reject(&.is_coinbase?).each do |transaction|
        # common rules
        raise "there must be 1 or less recipients" if transaction.recipients.size > 1
        raise "there must be 1 sender" if transaction.senders.size != 1

        sender = transaction.senders[0]

        amount_token = get_pending_batch(sender.address, processed_transactions, transaction.token, historic_per_address)
        amount_default = transaction.token == DEFAULT ? amount_token : get_pending_batch(sender.address, processed_transactions, DEFAULT, historic_per_address)

        as_recipients = transaction.recipients.select(&.address.==(sender.address))
        amount_token_as_recipients = as_recipients.reduce(0_i64) { |sum, recipient| sum + recipient.amount }
        amount_default_as_recipients = transaction.token == DEFAULT ? amount_token_as_recipients : 0_i64
