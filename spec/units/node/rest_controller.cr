
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
include Axentro::Core::Controllers
include Axentro::Core::Keys

private def asset_blockchain(api_path)
  with_factory do |block_factory, _|
    block_factory.add_slow_blocks(50)
    exec_rest_api(block_factory.rest.__v1_blockchain(context(api_path), no_params)) do |result|
      result["status"].to_s.should eq("success")
      yield result["result"]
    end
  end
end

private def asset_blockchain_header(api_path)
  with_factory do |block_factory, _|
    block_factory.add_slow_blocks(50)
    exec_rest_api(block_factory.rest.__v1_blockchain_header(context(api_path), no_params)) do |result|
      result["status"].to_s.should eq("success")
      yield result["result"]
    end
  end
end

describe RESTController do
  describe "__v1_blockchain" do
    it "should return the full blockchain with pagination defaults (page:0,per_page:20,direction:desc)" do
      asset_blockchain("/api/v1/blockchain") do |result|
        blocks = Array(Block).from_json(result["data"].to_json)
        blocks.size.should eq(20)
        blocks.first.index.should eq(100)
      end
    end
    it "should return the full blockchain with pagination specified direction (page:0,per_page:20,direction:asc)" do
      asset_blockchain("/api/v1/blockchain?direction=up") do |result|
        blocks = Array(Block).from_json(result["data"].to_json)
        blocks.size.should eq(20)
        blocks.first.index.should eq(0)
      end
    end
    it "should return the full blockchain with pagination specified direction (page:2,per_page:1,direction:desc)" do
      asset_blockchain("/api/v1/blockchain?page=2&per_page=1&direction=down") do |result|
        blocks = Array(Block).from_json(result["data"].to_json)
        blocks.size.should eq(1)
        blocks.first.index.should eq(98)
      end
    end
  end

  describe "__v1_blockchain_header" do
    it "should return the blockchain headers with pagination defaults (page:0,per_page:20,direction:desc)" do
      asset_blockchain_header("/api/v1/blockchain/header") do |result|
        blocks = Array(Blockchain::Header).from_json(result["data"].to_json)
        blocks.size.should eq(20)
        blocks.first[:index].should eq(100)
      end
    end
    it "should return the blockchain headers with pagination specified direction (page:0,per_page:20,direction:asc)" do
      asset_blockchain_header("/api/v1/blockchain/header/?direction=up") do |result|
        blocks = Array(Blockchain::Header).from_json(result["data"].to_json)
        blocks.size.should eq(20)
        blocks.first[:index].should eq(0)
      end
    end
    it "should return the blockchain headers with pagination specified direction (page:2,per_page:1,direction:desc)" do
      asset_blockchain_header("/api/v1/blockchain/header?page=2&per_page=1&direction=down") do |result|
        blocks = Array(Blockchain::Header).from_json(result["data"].to_json)
        blocks.size.should eq(1)
        blocks.first[:index].should eq(98)
      end
    end
  end

  describe "__v1_blockchain_size" do
    it "should return the full blockchain size when chain fits into memory" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_blockchain_size(context("/api/v1/blockchain/size"), no_params)) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["totals"]["total_size"].should eq(3)
          result["result"]["totals"]["total_fast"].should eq(0)
          result["result"]["totals"]["total_slow"].should eq(3)
          result["result"]["block_height"]["fast"].should eq(0)
          result["result"]["block_height"]["slow"].should eq(4)
        end
      end
    end
  end

  describe "__v1_block_index" do
    it "should return the block for the specified index" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index(context("/api/v1/block"), {index: 0})) do |result|
          result["status"].to_s.should eq("success")
          Block.from_json(result["result"]["block"].to_json)
        end
      end
    end
    it "should failure when block index is invalid" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index(context("/api/v1/block/99"), {index: 99})) do |result|
          result["status"].to_s.should eq("error")
          result["reason"].should eq("failed to find a block for the index: 99")
        end
      end
    end
  end

  describe "__v1_block_index_header" do
    it "should return the block header for the specified index" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index_header(context("/api/v1/block/0/header"), {index: 0})) do |result|
          result["status"].to_s.should eq("success")
          Blockchain::Header.from_json(result["result"].to_json)
        end
      end
    end
    it "should return failure when block index is invalid" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index_header(context("/api/v1/block/99/header"), {index: 99})) do |result|
          result["status"].to_s.should eq("error")
          result["reason"].should eq("failed to find a block for the index: 99")
        end
      end
    end
  end

  describe "__v1_block_index_transactions" do
    it "should return the block transactions for the specified index" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index_transactions(context("/api/v1/block/0/header"), {index: 2})) do |result|
          result["status"].to_s.should eq("success")
          Array(Transaction).from_json(result["result"]["transactions"].to_json)
          result["result"]["confirmations"].as_i.should eq(2)
        end
      end
    end
  end

  describe "__v1_transaction_id" do
    it "should return the transaction for the specified transaction id" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_id(context("/api/v1/transaction/#{transaction.id}"), {id: transaction.id})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["status"].to_s.should eq("accepted")
          Transaction.from_json(result["result"]["transaction"].to_json)
        end
      end
    end
    it "should return not found when specified transaction is not found" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_id(context("/api/v1/transaction/non-existing-txn-id"), {id: "non-existing-txn-id"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["status"].should eq("not found")
        end
      end
    end