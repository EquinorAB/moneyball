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

module ::Axentro::Core
  alias MinerWork = NamedTuple(start_nonce: BlockNonce, difficulty: Int32, block: Block)

  class MinerWorker < Tokoroten::Worker
    def task(message : String)
      work = MinerWork.from_json(message)

      block_nonce = work[:start_nonce]
      nonce_counter = 0

      latest_nonce_counter = nonce_counter
      time_now = __timestamp
      latest_time = time_now

      miner_nonce = MinerNonce.from(block_nonce)

      # just initialized so we can re-define it inside the loop each time
      block = work[:block]
      block_hash = ""

      loop do
        time_now = __timestamp

        # update with latest nonce and difficulty
        block = block.with_nonce(block_nonce).with_difficulty(work[:difficulty])
        block_hash = block.to_hash

        if calculate_pow_difficulty(block.mining_versi