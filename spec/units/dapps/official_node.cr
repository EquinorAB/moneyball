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

describe OfficialNode do
  describe "default non implemented methods" do
    it "should perform #setup" do
      with_factory do |block_factory, _|
        transaction_creator = OfficialNode.new(block_factory.add_slow_block.blockchain)
        transaction_creator.setup.should be_nil
      end
    end
    it "should perform #transaction_actions" do
      with_factory do |block_factory, _|
        transaction_creator = OfficialNode.new(block_factory.add_slow_block.blockchain)
        transaction_creator.transaction_actions.should eq(["create_official_node_slow", "create_official_node_fast"])
      end
    end
    it "should perform #transaction_related?" do
      with_factory do |block_factory, _|
        transaction_creator = OfficialNode.new(block_factory.add_slow_block.blockchain)
        transaction_creator.transaction_r