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
include Axentro::Core::NodeComponents
include Axentro::Core::Keys

describe SlowSync do
  describe "CREATE" do
    # incoming block is not in local db and is next in sequence
    it "should create incoming block in local db and broadcast onwards" do
      with_factory do |block_factory, _|
        blockchain = block_factory.blockchain
        database = blockchain.database

        block_factory.add_slow_block
        mining_block = blockchain.mining_block

        latest_slow = get_latest_slow(database)
        incoming_block = make_incoming_next_in_sequence(latest_slow, blockchain)

        has_block = database.get_block(incoming_block.ind