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
# require "../blockchain/*"
# require "../blockchain/block/*"
require "../fast_pool_database/*"
require "../fast_pool_database/migrations/*"
require "../modules/logger"

module ::Axentro::Core
  class FastPool
    MEMORY        = "%3Amemory%3A"