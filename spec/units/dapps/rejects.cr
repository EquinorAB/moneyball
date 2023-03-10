
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

describe Rejects do
  it "should perform #setup" do
    with_factory do |block_factory, _|
      rejects = Rejects.new(block_factory.add_slow_block.blockchain)
      rejects.setup.should be_nil
    end
  end
  it "should perform #transaction_actions" do
    with_factory do |block_factory, _|
      rejects = Rejects.new(block_factory.add_slow_block.blockchain)
      rejects.transaction_actions.size.should eq(0)
    end
  end
  it "should find a rejected transaction" do
    with_factory do |block_factory, transaction_factory|
      sender_address = transaction_factory.sender_wallet.address
      chain = block_factory.add_slow_blocks(2).chain
      transaction_id = chain.last.transactions.last.id
      rejects = Rejects.new(block_factory.blockchain)
      rejects.record_reject(transaction_id, sender_address, Exception.new("oops"))
      rejects.find(transaction_id).not_nil!.transaction_id.should eq(transaction_id)
    end
  end
  it "should find a rejected transaction using partial transaction id" do
    with_factory do |block_factory, transaction_factory|
      sender_address = transaction_factory.sender_wallet.address
      chain = block_factory.add_slow_blocks(2).chain
      transaction_id = chain.last.transactions.last.id
      rejects = Rejects.new(block_factory.blockchain)
      rejects.record_reject(transaction_id, sender_address, Exception.new("oops"))
      rejects.find(transaction_id[0, 8]).not_nil!.transaction_id.should eq(transaction_id)
    end
  end
  it "should find rejected transactions by address" do
    with_factory do |block_factory, transaction_factory|
      sender_address = transaction_factory.sender_wallet.address
      chain = block_factory.add_slow_blocks(2).chain
      transaction_id = chain.last.transactions.last.id
      rejects = Rejects.new(block_factory.blockchain)
      rejects.record_reject(transaction_id, sender_address, Exception.new("oops"))
      rejects.find_by_address(sender_address).size.should eq(1)
    end
  end
  it "should perform #transaction_related?" do
    with_factory do |block_factory, _|
      rejects = Rejects.new(block_factory.add_slow_block.blockchain)
      rejects.transaction_related?("action").should be_false
    end
  end
  it "should perform #valid_transaction?" do
    with_factory do |block_factory, _|
      chain = block_factory.add_slow_blocks(2).chain
      rejects = Rejects.new(block_factory.blockchain)
      result = rejects.valid_transactions?(chain.last.transactions)
      result.failed.size.should eq(0)
      result.passed.size.should eq(1)
    end
  end
  describe "record_reject" do
    it "should record a rejected transaction with exception message" do
      with_factory do |block_factory, transaction_factory|
        sender_address = transaction_factory.sender_wallet.address
        chain = block_factory.add_slow_blocks(2).chain
        transaction_id = chain.last.transactions.last.id
        rejects = Rejects.new(block_factory.blockchain)
        rejects.record_reject(transaction_id, sender_address, Exception.new("oops"))
        if reject = block_factory.database.find_reject(transaction_id)
          reject.reason.should eq("oops")
        else
          fail "no reject found"
        end
      end
    end
    it "should record a rejected transaction with default exception message" do
      with_factory do |block_factory, transaction_factory|
        sender_address = transaction_factory.sender_wallet.address
        chain = block_factory.add_slow_blocks(2).chain
        transaction_id = chain.last.transactions.last.id
        rejects = Rejects.new(block_factory.blockchain)
        rejects.record_reject(transaction_id, sender_address, Exception.new)
        if reject = block_factory.database.find_reject(transaction_id)
          reject.reason.should eq("unknown")
        else
          fail "no reject found"
        end
      end
    end
  end
end