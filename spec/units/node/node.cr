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

describe Node do
  it "should not process a fast block that is not signed by an official fast node" do
    with_factory do |block_factory, _|
      node = block_factory.node
      not_official_fast_node_wallet = Wallet.from_json(Wallet.create(true).to_json)
      block = create_fast_block(not_official_fast_node_wallet)
      node.fast_block_was_signed_by_official_fast_node?(block).should eq(false)
   