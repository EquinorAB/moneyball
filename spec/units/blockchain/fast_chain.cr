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

require "./../../spec_helper"
require "benchmark"

include Axentro::Core
include Hashes
include Units::Utils
include Axentro::Core::DApps::BuildIn
include Axentro::Core::Controllers

describe Blockchain do
  describe "valid_transactions_for_fast_block" do
    it "should the latest index and valid aligned transactions" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_fast_send(200000000_i64)
        transaction2 = transaction_factory.make_fast_send(200000000_i64)
        blockchain = block_factory.blockchain

        block_factory.add_slow_blocks(4)

        transaction1.id
        transaction2.id

        blockchain.add_transaction(transaction1, false)
        blockchain.add_transaction(transaction2, false)

        result = blockchain.valid_transactions_for_fast_block
        result[:transactions].size.should eq(3)
        result[:latest_index].should eq(1)
      end
    end
  end

  describe "mint_fast_block" do
