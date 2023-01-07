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
    def initialize(
      @is_private : Bool,
      @is_testnet : Bool,
      @bind_host : String,
      @bind_port : Int32,
      @public_host : String?,
      @public_port : Int32?,
      @ssl : Bool?,
      @connect_host : String?,
      @connect_port : Int32?,
      @wallet : Wallet?,
      @wallet_address : String,
      @database_path : String,
      @database : Database,
      @developer_fund : DeveloperFund?,
      @official_nodes : OfficialNodes?,
      @exit_on_unofficial : Bool,
      @security_level_percentage : Int64,
      @sync_chunk_size : Int32,
      @record_nonces : Bool,
      @max_miners : Int32,
      @max_private_nodes : Int32,
      @whitelist : Array(String),
      @whitelist_message : String,
      @metrics_whitelist : Array(String),
      @use_ssl : Bool = false
    )
      welcome

      @phase = SetupPhase::NONE

      @network_type = @is_testnet ? "testnet" : "mainnet"
      @blockchain = Blockchain.new(@network_type, @wallet, @wallet_address, @database_path, @database, @developer_fund, @official_nodes, @security_level_percentage, @sync_chunk_size, @record_nonces, @max_miners, is_standalone?)
      @chord = Chord.new(@database, @connect_host, @connect_port, @public_host, @public_port, @ssl, @network_type, @is_private, @use_ssl, @max_private_nodes, @wallet_address, @blockchain.official_node, @exit_on_unofficial, @whitelist, @whitelist_message)
      @miners_manager = MinersManager.new(@blockchain, @is_private)
      @clients_manager = ClientsManager.new(@blockchain)

      @limiter = RateLimiter(String).new
      @limiter.bucket(:incoming_nonces, 1_u32, 30.seconds)

      # Configure HTTP throttle
      Defense.store = Defense::MemoryStore.new
      Defense.throttle("throttle requests per second for creating transactions via API", limit: 500, period: 1) do |request|
        if @phase == SetupPhase::DONE
          if request.resource == "/api/v1/transaction" && request.method == "POST"
            "request"
          end
        end
      end

      Defense.throttle("throttle requests per second for general API", limit: 10, period: 1) do |request|
        if @phase == SetupPhase::DONE
          remote_connection = NetworkUtil.get_remote_connection(request)
          if request.resource.starts_with?("/api")
            remote_connection.ip
          end
        end
      end

      Def