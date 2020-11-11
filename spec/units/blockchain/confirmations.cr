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
  it "it should get the number of confirmations for a transaction with just slow blocks" do
    with_factory do |block_factory, transaction_factory|
      block_factory.add_slow_blocks(1)
      sleep 0.001
      block_factory.add_slow_blocks(1)
      sleep 0.001
      block_factory.add_slow_block([tra