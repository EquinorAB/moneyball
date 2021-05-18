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

module ::Axentro::Core::NonceModels
  struct MinerNonce
    include JSON::Serializable

    getter mid : String = "0"
    getter value : BlockNonce
    getter timestamp : Int64 = 0_i64
    getter address : String = "0"
    get