
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

require "./blockchain/*"
require "./blockchain/domain_model/*"
require "./blockchain/validators/*"
require "./blockchain/chain/*"
require "./blockchain/rewards/*"
require "./dapps"
require "./node/components/metrics"

module ::Axentro::Core
  struct ReplaceBlocksResult
    property index : Int64
    property success : Bool

    def initialize(@index, @success); end
  end

  class Blockchain
    TOKEN_DEFAULT = Core::DApps::BuildIn::UTXO::DEFAULT

    alias Header = NamedTuple(
      index: Int64,
      nonce: BlockNonce,
      prev_hash: String,
      merkle_tree_root: String,
      timestamp: Int64,
      difficulty: Int32,
    )

    getter wallet_address : String
    getter max_miners : Int32

    @network_type : String
    @sync_chunk_size : Int32
    @record_nonces : Bool
    @node : Node?
    @mining_block : Block?
    @block_reward_calculator = BlockRewardCalculator.init
    @max_miners : Int32
    @is_standalone : Bool
    @database_path : String

    def initialize(@network_type : String, @wallet : Wallet?, @wallet_address : String, @database_path : String, @database : Database, @developer_fund : DeveloperFund?, @official_nodes : OfficialNodes?, @security_level_percentage : Int64, @sync_chunk_size : Int32, @record_nonces : Bool, @max_miners : Int32, @is_standalone : Bool)
      initialize_dapps
      SlowTransactionPool.setup
      FastTransactionPool.setup(@database_path)
      MinerNoncePool.setup

      info "Security Level Percentage used for blockchain validation is #{@security_level_percentage}"
      info "Blockchain sync chunk size is #{@sync_chunk_size}"
    end

    def database
      @database
    end

    def network_type
      @network_type
    end

    def chain
      @database.get_blocks_via_query("select * from blocks order by timestamp asc limit 250")
    end

    def setup(@node : Node)
      setup_dapps

      if @database.total_blocks == 0
        if @is_standalone
          push_genesis
          refresh_mining_block
        end
      else
        if @is_standalone
          info "validating db for standalone node"
          @database.validate_local_db_blocks
        end
      end
    end

    def database
      @database
    end

    def node
      @node.not_nil!
    end

    private def push_genesis
      push_slow_block(genesis_block)
    end

    def get_genesis_block : Block
      @database.get_block(0).not_nil!.as(Block)
    end

    def valid_nonce?(block_nonce : BlockNonce) : Bool
      mining_block.with_nonce(block_nonce).valid_block_nonce?(mining_block_difficulty)
    end

    def valid_block?(block : Block, skip_transactions : Bool = false, doing_replace : Bool = false) : Block?
      block if block.valid?(self, skip_transactions, doing_replace)
    end

    def mining_block_difficulty : Int32
      return ENV["AX_SET_DIFFICULTY"].to_i if ENV.has_key?("AX_SET_DIFFICULTY")
      the_mining_block = @mining_block
      if the_mining_block
        the_mining_block.difficulty
      else
        @database.get_highest_block_for_kind!(BlockKind::SLOW).difficulty
      end
    end

    def mining_block_difficulty_miner : Int32
      return ENV["AX_SET_DIFFICULTY"].to_i if ENV.has_key?("AX_SET_DIFFICULTY")
      block_difficulty_to_miner_difficulty(mining_block_difficulty)
    end

    def mining_block_difficulty_for_miner(difficulty : Int32) : Int32
      return ENV["AX_SET_DIFFICULTY"].to_i if ENV.has_key?("AX_SET_DIFFICULTY")
      block_difficulty_to_miner_difficulty(difficulty)
    end

    def replace_block(block : Block)
      target_index = chain.index(&.index.==(block.index))
      if target_index
        # validate during replace block
        # @database.delete_block(block.index)
        # check block is valid here (including checking transactions) - we are in replace
        block.valid?(self, false, true)
        @database.inplace_block(block)
      else
        warning "replacement block location not found in local chain"
      end
    end

    def push_slow_block(block : Block)
      _push_block(block)
      clean_slow_transactions
      clean_fast_transactions

      debug "after clean_transactions, now calling refresh_mining_block in push_block"
      refresh_mining_block
      block
    end

    private def _push_block(block : Block)
      debug "sending #{block.kind} block to DB with timestamp of #{block.timestamp}"
      @database.inplace_block(block)
    end

    def add_transaction(transaction : Transaction, with_spawn : Bool = true)
      with_spawn ? spawn { _add_transaction(transaction) } : _add_transaction(transaction)
    end

    private def _add_transaction(transaction : Transaction)
      vt = TransactionValidator.validate_common([transaction], @network_type)

      # TODO - could reject in bulk also
      vt.failed.each do |ft|
        METRICS_TRANSACTIONS_COUNTER[kind: "rejected"].inc
        rejects.record_reject(ft.transaction.id, Rejects.address_from_senders(ft.transaction.senders), ft.reason)
        node.wallet_info_controller.update_wallet_information([ft.transaction])
      end

      vt.passed.each do |_transaction|
        if _transaction.kind == TransactionKind::FAST
          if node.fastnode_is_online?
            if node.i_am_a_fast_node?
              debug "adding fast transaction to pool (I am a fast node): #{_transaction.id}"
              METRICS_TRANSACTIONS_COUNTER[kind: "fast"].inc
              FastTransactionPool.add(_transaction)
            end
          else
            debug "chain is not mature enough for FAST transactions so adding to slow transaction pool: #{_transaction.id}"
            _transaction.kind = TransactionKind::SLOW
            METRICS_TRANSACTIONS_COUNTER[kind: "slow"].inc
            SlowTransactionPool.add(_transaction)
          end
        else
          METRICS_TRANSACTIONS_COUNTER[kind: "slow"].inc
          SlowTransactionPool.add(_transaction)
        end
        node.wallet_info_controller.update_wallet_information([_transaction])
      end
    end

    def add_miner_nonce(miner_nonce : MinerNonce, with_spawn : Bool = true)
      with_spawn ? spawn { _add_miner_nonce(miner_nonce) } : _add_miner_nonce(miner_nonce)
    end

    private def _add_miner_nonce(miner_nonce : MinerNonce)
      # if valid_nonce?(miner_nonce.value)
      debug "adding miner nonce to pool: #{miner_nonce.value}"
      MinerNoncePool.add(miner_nonce) if MinerNoncePool.find(miner_nonce).nil?
      # end

    rescue e : Exception
      warning "nonce was not added to pool due to: #{e}"
    end

    def miner_nonce_pool
      MinerNoncePool
    end

    private def get_genesis_block_transactions
      dev_fund = @developer_fund ? DeveloperFund.transactions(@developer_fund.not_nil!.get_config) : [] of Transaction
      official_nodes = @official_nodes ? OfficialNodes.transactions(@official_nodes.not_nil!.get_config, dev_fund) : [] of Transaction
      dev_fund + official_nodes
    end

    def genesis_block : Block
      genesis_index = 0_i64
      genesis_transactions = get_genesis_block_transactions
      genesis_nonce = "0"
      genesis_prev_hash = "genesis"
      genesis_timestamp = 0_i64
      genesis_difficulty = Consensus::MINER_DIFFICULTY_TARGET
      kind = BlockKind::SLOW
      address = "genesis"
      public_key = ""
      signature = ""
      hash = ""
      version = BlockVersion::V2
      hash_version = HashVersion::V2
      merkle_tree_root = MerkleTreeCalculator.new(hash_version).calculate_merkle_tree_root(genesis_transactions)
      checkpoint = ""
      mining_version = MiningVersion::V1

      Block.new(
        genesis_index,
        genesis_transactions,
        genesis_nonce,
        genesis_prev_hash,
        genesis_timestamp,
        genesis_difficulty,
        kind,
        address,
        public_key,
        signature,
        hash,
        version,
        hash_version,
        merkle_tree_root,
        checkpoint,
        mining_version
      )
    end

    def available_actions : Array(String)
      OfficialNode.apply_exclusions(@dapps).flat_map(&.transaction_actions)
    end

    def pending_miner_nonces : MinerNonces
      MinerNoncePool.all
    end

    def pending_slow_transactions : Transactions
      SlowTransactionPool.all
    end

    def pending_fast_transactions : Transactions
      FastTransactionPool.all
    end

    def embedded_slow_transactions : Transactions
      SlowTransactionPool.embedded
    end

    def embedded_fast_transactions : Transactions
      FastTransactionPool.embedded
    end

    def replace_with_block_from_peer(block : Block)
      replace_block(block)
      debug "replace transactions in indices array that were in the block being replaced with those from the replacement block"
      debug "cleaning the transactions because of the replacement"
      clean_slow_transactions_used_in_block(block)
      clean_fast_transactions_used_in_block(block)
      debug "refreshing mining block after accepting new block from peer"
      refresh_mining_block if block.kind == "SLOW"
    end

    def mining_block : Block
      debug "calling refresh_mining_block in mining_block" unless @mining_block
      refresh_mining_block unless @mining_block
      @mining_block.not_nil!
    end

    def calculate_coinbase_slow_transaction(coinbase_amount, the_latest_index, embedded_slow_transactions)
      # pay the fees to the fastnode for maintenance (unless there are no more blocks to mine)
      fee = (the_latest_index >= @block_reward_calculator.max_blocks) ? 0_i64 : total_fees(embedded_slow_transactions)
      create_coinbase_slow_transaction(coinbase_amount, fee, node.miners)
    end

    def refresh_mining_block
      # we don't want to delete any of the miner nonces unless this refresh is for the next block