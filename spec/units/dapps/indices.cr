
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

describe Indices do
  it "should perform #setup" do
    with_factory do |block_factory, _|
      indices = Indices.new(block_factory.add_slow_block.blockchain)
      indices.setup.should be_nil
    end
  end

  describe "#get" do
    it "should return the indice for the given transaction" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_blocks(2).chain
        indices = Indices.new(block_factory.blockchain)
        indices.record(chain)
        indices.get(chain.last.transactions.last.id).should eq(4)
      end
    end
    it "should return nil if the transaction is not found in the chain" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_blocks(2).chain
        indices = Indices.new(block_factory.blockchain)
        indices.record(chain)
        indices.get("non-existing-transaction-id").should be_nil
      end
    end
    it "should perform #transaction_actions" do
      with_factory do |block_factory, _|
        indices = Indices.new(block_factory.add_slow_block.blockchain)
        indices.transaction_actions.size.should eq(0)
      end
    end
    it "should perform #transaction_related?" do
      with_factory do |block_factory, _|
        indices = Indices.new(block_factory.add_slow_block.blockchain)
        indices.transaction_related?("action").should be_true
      end
    end

    describe("valid_transactions") do
      it "should be valid if not in chain already or in current block" do
        with_factory do |block_factory, transaction_factory|
          indices = Indices.new(block_factory.blockchain)
          transaction = transaction_factory.make_send(200000000_i64)

          result = indices.valid_transactions?([transaction])
          result.passed.size.should eq(1)
          result.failed.size.should eq(0)
          result.passed.first.should eq(transaction)
        end
      end
      it "should not be valid if already in the chain" do
        with_factory do |block_factory, _|
          indices = Indices.new(block_factory.blockchain)
          chain = block_factory.add_slow_blocks(2).chain
          transaction = chain.last.transactions.first

          result = indices.valid_transactions?([transaction])
          result.passed.size.should eq(0)

          result.failed.size.should eq(1)
          result.failed.first.transaction.should eq(transaction)
          result.failed.first.reason.should eq("the transaction #{transaction.id} already exists in block: 4")
        end
      end
      it "should not be valid if in the current block" do
        with_factory do |block_factory, transaction_factory|
          indices = Indices.new(block_factory.blockchain)
          transaction = transaction_factory.make_send(200000000_i64)

          result = indices.valid_transactions?([transaction, transaction])
          result.passed.size.should eq(0)

          result.failed.size.should eq(1)
          result.failed.first.transaction.should eq(transaction)
          result.failed.first.reason.should eq("the transaction #{transaction.id} already exists in the same block")
        end
      end
    end
  end

  describe "#define_rpc?" do
    describe "#transaction" do
      it "should return a transaction for the supplied transaction id" do
        with_factory do |block_factory, _|
          block_factory.add_slow_blocks(10)
          transaction = block_factory.chain[1].transactions.first
          payload = {call: "transaction", transaction_id: transaction.id}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
            data = JSON.parse(result)
            data["status"].should eq("accepted")
            data["transaction"].should eq(JSON.parse(transaction.to_json))
          end
        end
      end

      it "should return a transaction for the supplied partial transaction id" do
        with_factory do |block_factory, _|
          block_factory.add_slow_blocks(10)
          transaction = block_factory.chain[1].transactions.first
          payload = {call: "transaction", transaction_id: transaction.id[0, 8]}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
            data = JSON.parse(result)
            data["status"].should eq("accepted")
            data["transaction"].should eq(JSON.parse(transaction.to_json))
          end
        end
      end

      it "should raise an exception for the invalid transaction id" do
        with_factory do |block_factory, _|
          payload = {call: "transaction", transaction_id: "invalid-transaction-id"}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
            result.should eq("{\"status\":\"not found\",\"transaction\":null}")
          end
        end
      end
    end
  end
end