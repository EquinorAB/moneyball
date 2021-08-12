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

module ::Axentro::Core::NodeComponents
  enum SlowSyncState
    CREATE
    REPLACE
    REJECT_OLD
    REJECT_VERY_OLD
    SYNC
  end

  enum RejectBlockReason
    OLD      # same index but local block is younger
    VERY_OLD # some old index
  end

  struct RejectBlock
    include JSON::Serializable
    property reason : RejectBlockReason
    property rejected : Block
    property latest : Block
    property same : Block?

    def initialize(@reason, @rejected, @latest, @same); end
  end

  class SlowSync
    def initialize(@incoming_block : Block, @mining_block : Block, @has_block : Block?, @latest_slow : Block); end

    def process : SlowSyncState
      if @has_block
        already_in_db(@has_block.not_nil!.as(Block))
      else
        not_in_db
      end
    end

    private def not_in_db
      # if incoming block next in sequence
      if @incoming_block.index == @latest_slow.index + 2
        SlowSyncState::CREATE
      else
        # if incoming block not next in sequence
        if @incoming_block.index > @latest_slow.index 