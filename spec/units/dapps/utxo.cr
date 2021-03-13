
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

describe UTXO do
  describe "#get_for_batch" do
    it "should get the amount for the supplied token and address" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_blocks(10).chain
        utxo = UTXO.new(block_factory.blockchain)
        utxo.record(chain)
        address = chain[1].transactions.first.recipients.first.address
        historic_per_address = {address => [TokenQuantity.new(TOKEN_DEFAULT, 11999965560_i64)]}

        utxo.get_for_batch(address, TOKEN_DEFAULT, historic_per_address).should eq(11999965560_i64)
      end
    end
  end

  describe "#get_for_batch" do
    context "when address does not exist" do
      it "should return 0 when the number of blocks is less than confirmations and the address is not found" do
        with_factory do |block_factory, _|
          chain = block_factory.add_slow_block.chain
          utxo = UTXO.new(block_factory.blockchain)
          utxo.record(chain)
          historic_per_address = {} of String => Array(TokenQuantity)

          utxo.get_for_batch("address-does-not-exist", TOKEN_DEFAULT, historic_per_address).should eq(0)
        end
      end

      it "should return address amount when the number of blocks is greater than confirmations and the address is not found" do
        with_factory do |block_factory, _|
          chain = block_factory.add_slow_blocks(10).chain
          utxo = UTXO.new(block_factory.blockchain)
          utxo.record(chain)
          historic_per_address = {} of String => Array(TokenQuantity)

          utxo.get_for_batch("address-does-not-exist", TOKEN_DEFAULT, historic_per_address).should eq(0)
        end
      end
    end

    context "when token does not exist" do
      it "should return 0 when the number of blocks is less than confirmations and the token is not found" do
        with_factory do |block_factory, _|
          chain = block_factory.add_slow_block.chain
          utxo = UTXO.new(block_factory.blockchain)
          utxo.record(chain)
          address = chain[1].transactions.first.recipients.first.address
          historic_per_address = {address => [TokenQuantity.new(TOKEN_DEFAULT, 11999965560_i64)]}

          utxo.get_for_batch(address, "UNKNOWN", historic_per_address).should eq(0)
        end
      end

      it "should return address amount when the number of blocks is greater than confirmations and the token is not found" do
        with_factory do |block_factory, _|
          chain = block_factory.add_slow_blocks(10).chain
          utxo = UTXO.new(block_factory.blockchain)
          utxo.record(chain)
          address = chain[1].transactions.first.recipients.first.address
          historic_per_address = {address => [TokenQuantity.new(TOKEN_DEFAULT, 11999965560_i64)]}

          utxo.get_for_batch(address, "UNKNOWN", historic_per_address).should eq(0)
        end
      end
    end
  end

  describe "#get_pending_batch" do
    it "should get pending transactions amount for the supplied address in the supplied transactions" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_block.chain
        utxo = UTXO.new(block_factory.blockchain)
        utxo.record(chain)

        transactions = chain.reject(&.prev_hash.==("genesis")).flat_map(&.transactions)
        address = chain[1].transactions.first.recipients.first.address
        expected_amount = transactions.flat_map { |txn| txn.recipients.select(&.address.==(address)) }.sum(&.amount) * 2
        historic_per_address = {address => [TokenQuantity.new(TOKEN_DEFAULT, expected_amount - 1199999373_i64)]}

        utxo.get_pending_batch(address, transactions, TOKEN_DEFAULT, historic_per_address).should eq(expected_amount)
      end
    end

    it "should get pending transactions amount for the supplied address when no transactions are supplied" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_block.chain
        utxo = UTXO.new(block_factory.blockchain)
        utxo.record(chain)

        transactions = [] of Transaction
        address = chain[1].transactions.first.recipients.first.address
        expected_amount = chain.reject(&.prev_hash.==("genesis")).flat_map { |blk| blk.transactions.first.recipients.select(&.address.==(address)) }.sum(&.amount)
        historic_per_address = {address => [TokenQuantity.new(TOKEN_DEFAULT, expected_amount)]}

        utxo.get_pending_batch(address, transactions, TOKEN_DEFAULT, historic_per_address).should eq(expected_amount)
      end
    end

    context "when chain is empty" do
      it "should get pending transactions amount for the supplied address when no transactions are supplied and the chain is empty" do
        with_factory do |block_factory, _|
          chain = [] of Block
          utxo = UTXO.new(block_factory.blockchain)
          utxo.record(chain)
          historic_per_address = {} of String => Array(TokenQuantity)

          transactions = [] of Transaction
          address = "any-address"

          utxo.get_pending_batch(address, transactions, TOKEN_DEFAULT, historic_per_address).should eq(0)
        end
      end

      it "should get pending transactions when no transactions are supplied and the chain is empty and the address is unknown" do
        with_factory do |block_factory, _|
          chain = [] of Block
          utxo = UTXO.new(block_factory.blockchain)