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

include Axentro::Core
include Units::Utils
include Axentro::Core::DApps::BuildIn
include Axentro::Core::Controllers

describe Token do
  it "should perform #setup" do
    with_factory do |block_factory, _|
      token = Token.new(block_factory.add_slow_block.blockchain)
      token.setup.should be_nil
    end
  end
  it "should perform #transaction_actions" do
    with_factory do |block_factory, _|
      token = Token.new(block_factory.add_slow_block.blockchain)
      token.transaction_actions.should eq(["create_token", "update_token", "lock_token", "burn_token"])
    end
  end
  describe "#transaction_related?" do
    it "should return true when action is related" do
      with_factory do |block_factory, _|
        token = Token.new(block_factory.add_slow_block.blockchain)
        token.transaction_related?("create_token").should be_true
      end
    end
    it "should return false when action is not related" do
      with_factory do |block_factory, _|
        token = Token.new(block_factory.add_slow_block.blockchain)
        token.transaction_related?("unrelated").should be_false
      end
    end
  end

  describe "#valid_transaction?" do
    it "should pass when valid transaction" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_create_token("KINGS", 10_i64)
        chain = block_factory.add_slow_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        transactions = chain.last.transactions + [transaction]

        result = token.valid_transactions?(transactions)
        result.passed.size.should eq(1)
        result.failed.size.should eq(0)
        result.passed.should eq([transaction])