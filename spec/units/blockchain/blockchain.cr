
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
  describe "setup" do
    it "should create a genesis block" do
      with_factory do |block_factory|
        block = block_factory.chain.first
        block.kind.should eq("SLOW")
        block.prev_hash.should eq("genesis")
      end
    end
  end

  describe "mining_block_difficulty_miner" do
    it "should return the miner difficulty" do
      with_factory do |block_factory|
        block_factory.blockchain.mining_block_difficulty_miner.should eq(0)
      end
    end
  end

  describe "mining_block_difficulty" do
    it "should return the chian difficulty" do
      with_factory do |block_factory|
        block_factory.blockchain.mining_block_difficulty.should eq(0)
      end
    end
  end

  # describe "replace_mixed_chain" do
  #   it "should return false if no subchains and do nothing" do
  #     with_factory do |block_factory|
  #       before = block_factory.chain
  #       expected_result = ReplaceBlocksResult.new(0_i64, false)
  #       block_factory.blockchain.replace_mixed_chain(nil).should eq(expected_result)
  #       before.should eq(block_factory.chain)
  #     end
  #   end

  #   it "should return true and replace chain when fast and slow blocks in chain" do
  #     with_factory do |block_factory|
  #       chain = block_factory.add_slow_blocks(6).add_fast_blocks(10).chain
  #       fast_sub_chain = chain.select(&.is_fast_block?)
  #       slow_block_1 = chain[2].as(Block)
  #       slow_sub_chain = chain.select(&.is_slow_block?)

  #       database = Axentro::Core::Database.in_memory
  #       blockchain = Blockchain.new("testnet", block_factory.node_wallet, block_factory.node_wallet.address, "", database, nil, nil, 20, 100, false, 512, true)
  #       blockchain.setup(block_factory.node)
  #       blockchain.push_slow_block(slow_block_1)
  #       expected = (blockchain.chain + slow_sub_chain[2..-1] + fast_sub_chain[0..-1]).map(&.index).sort
  #       expected_result = ReplaceBlocksResult.new(19_i64, true)
  #       blockchain.replace_mixed_chain(slow_sub_chain[2..-1] + fast_sub_chain[0..-1]).should eq(expected_result)
  #       blockchain.chain.map(&.index).sort.should eq(expected)
  #     end
  #   end
  # end

  describe "add_transaction" do
    it "should add a transaction to the pool" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(200000000_i64)
        blockchain = block_factory.blockchain
        blockchain.add_transaction(transaction, false)
        blockchain.pending_slow_transactions.first.should eq(transaction)
        blockchain.embedded_slow_transactions.first.should eq(transaction)
      end
    end

    it "should reject a transaction if invalid" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(-200000000_i64)
        blockchain = block_factory.blockchain
        blockchain.add_transaction(transaction, false)
        blockchain.pending_slow_transactions.size.should eq(0)
        blockchain.embedded_slow_transactions.size.should eq(0)
        if reject = blockchain.rejects.find(transaction.id)
          reject.reason.should eq("the amount is out of range")
        else
          fail "no rejects found"
        end
      end
    end

    it "should not change the wallet balance for the default token with an arbitary action" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(10)
        address_amount = block_factory.database.get_address_amount(transaction_factory.recipient_wallet.address)
        address_amount.size.should eq(1)
        address_amount.first.amount.should eq(0)
        address_amount.first.token.should eq(TOKEN_DEFAULT)

        transaction = transaction_factory.make_transaction("something_stupid", 200000000_i64, "AXNT")
        block_factory.add_slow_block([transaction])
        address_amount = block_factory.database.get_address_amount(transaction_factory.recipient_wallet.address)
        address_amount.size.should eq(1)
        address_amount.first.amount.should eq(0)
        address_amount.first.token.should eq(TOKEN_DEFAULT)
      end
    end

    it "should not change the wallet balance for a custom token with an arbitary action" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(10)
        address_amount = block_factory.database.get_address_amount(transaction_factory.recipient_wallet.address)
        address_amount.size.should eq(1)
        address_amount.first.amount.should eq(0)
        address_amount.first.token.should eq(TOKEN_DEFAULT)

        transaction = transaction_factory.make_transaction("something_stupid", 200000000_i64, "KINGS")
        block_factory.add_slow_block([transaction])
        address_amount = block_factory.database.get_address_amount(transaction_factory.recipient_wallet.address)
        block_factory.blockchain.rejects.find(transaction.id).should be_nil
        address_amount.size.should eq(1)
        address_amount.first.amount.should eq(0)
        address_amount.first.token.should eq(TOKEN_DEFAULT)
      end
    end

    it "should reject a transaction when trying to fake the sender" do
      victim_wallet = Wallet.from_json(Wallet.create(true).to_json)
      hacker_wallet = Wallet.from_json(Wallet.create(true).to_json)

      sender = Sender.new(victim_wallet.address, hacker_wallet.public_key, 10000000_i64, 10000000_i64, "0")
      recipient = Recipient.new(hacker_wallet.address, 10000000_i64)

      transaction_id = Transaction.create_id
      unsigned_transaction = Transaction.new(
        transaction_id,
        "send", # action
        [sender],
        [recipient],
        [] of Transaction::Asset,
        [] of Transaction::Module,
        [] of Transaction::Input,
        [] of Transaction::Output,
        "",     # linked
        "0",    # message
        "AXNT", # token
        "0",    # prev_hash
        0_i64,  # timestamp
        1,      # scaled
        TransactionKind::SLOW,
        TransactionVersion::V1
      )
      transaction = unsigned_transaction.as_signed([hacker_wallet])

      with_factory do |block_factory, _|
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        if reject = block_factory.blockchain.rejects.find(transaction.id)