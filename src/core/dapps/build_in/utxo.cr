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
        # when tokens are created or