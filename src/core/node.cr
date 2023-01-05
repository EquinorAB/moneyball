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

require "./node/*"

module ::Axentro::Core
  struct NodeConnection
    property host : String
    property port : Int32
    property ssl : Bool

    def initialize(@host, @port, @ssl); end

    def to_s
      "#{host}:#{port}"
    end
  end

  class Node < HandleSocket
    alias Network = NamedTuple(
      prefix: String,
      name: String,
    )

    property phase : SetupPhase

    getter blockchain : Blockchain
    getter network_type : String
    getter chord : Chord
    getter database : Database
    getter miners_manager : MinersManager

    @miners_manager : MinersManager
    @clients_manager : ClientsManager

    @rpc_controller : Controllers::RPCController
    @rest_controller : Controllers::RESTController
    @pubsub_controller : Controllers::PubsubController
    @wallet_info_controller : Controllers::WalletInfoController

    MAX_SYNC_RETRY = 20
    @sync_retry_count : Int32 = 2
    @sync_retry_list : Set(NodeConnection) = Set(NodeConnection).new

    # child node gets this from parent on setup
    @sync_blocks_target_index : Int64 = 0_i64
    @validation_hash : String = ""

    # ameba:disable Metrics/CyclomaticComplexity
    def i