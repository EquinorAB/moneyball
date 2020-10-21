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

require "random"
require "file_utils"
require "./utils"
require "./client"
require "yaml"

module ::E2E
  ALL_PUBLIC  = 0
  ALL_PRIVATE = 1
  ONE_PRIVATE = 2

  CONFIRMATION = 3

  class Runner
    @db_name : String

    @node_ports : Array(Int32)
    @node_ports_public