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

module ::Axentro::Core::BlockValidator
  extend self

  include Axentro::Common
  include Logger

  def validate_slow(block : Block, blockchain : Blockchain, skip_transactions : Bool = false, doing_replace : Bool = false) : ValidatedBlock
    if block.index == 0_i64
      validate_genesis(block)
    else
      validate_slow_block(block, blockchain, skip_transactions, doing_replace)
    end
  end

  def validate_fast(block : Block, blockchain : Blockchain, skip_transactions : Bool = false, doing_replace : Bool = false) : ValidatedBlock
    validate_fast_block(block, blockchain, skip_transactions, doing_replace)
  end

  def quick_validate(block : Block, prev_block : Block) : ValidatedBlock
    BlockValidator::Rules.rule_prev_hash(block, prev_block)
    BlockValidator::Rules.rule_merkle_tree(block)

    ValidatedBlock.new(true, block)
  rescue e : Axentro::Common::AxentroException
    ValidatedBlock.new(false, block, e.message || "unknown error")
  rescue e : Exception
    error("#{e.class}: #{e.message || "unknown error"}\n#{e.backtrace.join("\n")}")
    ValidatedBlock.new(false, block, "unexpected error: #{e.message || "unknown error"}")
  end

  def checkpoint_validate(block : Block, blocks : Array(Block)) : ValidatedBlock
    result = ValidatedBlock.new(true, block)
    actual = MerkleTreeCalculator.new(HashVersion::V2).calculate_merkle_tree_root(blocks)
    if actual != block.checkpoint
      result = ValidatedBlock.new(false, block, "checkpoint validation for index: #{block.index} failed. Actual #{actual} did not match expected #{block.checkpoint}")
    end
    result
  rescue e : Exception
    error("#{e.class}: #{e.message || "unknown error"}\n#{e.backtrace.join("\n")}")
    ValidatedBlock.new(false, block, "unexpected error: #{e.message || "unknown error"}")
  end

  def validate_genesis(block : Block)
    BlockValidator::Rules.rule_genesis(block)
    ValidatedBlock.new(true, block)
  rescue e : Axentro::Common::AxentroException
    ValidatedBlock.new(false, block, e.message || "unknown error")
  rescue e : Exception
    error("#{e.class}: #{e.message || "unknown error"}\n#{e.backtrace.join("\n")}")
    ValidatedBlock.new(false, block, "unexpected error: #{e.message || "unknown error"}")
  end

  def validate_slow_block(block : Block, blockchain : Blockchain, skip_transactions : Bool = false, doing_replace : Bool = false) : ValidatedBlock
    chain_network = blockchain.database.chain_network_kind
    block_network = Address.get_network_from_address(block.address)

    prev_block_index = block.index - 2_i64
    _prev_block = blockchain.database.get_previous_slow_from(prev_block_index)
    raise AxentroException.new("(slow_block::valid?) error finding previous slow block: #{prev_block_index} for current block: #{block.index}") if _prev_block.nil?
    prev_block = _prev_block.not_nil!

    BlockValidator::Rules.rule_network_type(chain_network, block_network)

    BlockValidator::Rules.rule_prev_block_slow_index(doing_replace, blockchain, block.index)

    BlockValidator::Rules.rule_prev_hash(block, prev_block)

    BlockValidator::Rules.rule_slow_transactions(skip_transactions, block.transactions, blockchain, block.index)

    BlockValidator::Rules.rule_timestamp(block.timestamp, prev_block, 0_i64)

    BlockValidator::Rules.rule_difficulty(block)

    BlockValidator::Rules.rule_merkle_tree(block)

    ValidatedBlock.new(true, block)
  rescue e : Axentro::Common::AxentroException
    ValidatedBlock.new(false, block, e.message || "unknown error")
  rescue e : Exception
    error("#{e.class}: #{e.message || "unknown error"}\n#{e.backtrace.join("\n")}")
    ValidatedBlock.new(false, block, "unexpected error: #{e.message || "unknown error"}")
  end

  def validate_fast_block(block : Block, blockchain : Blockchain, skip_transactions : Bool = false, doing_replace : Bool = false) : ValidatedBlock
    chain_network = blockchain.database.chain_network_kind
    block_network = Address.get_network_from_address(block.address)

    prev_block_index = block.index - 2_i64
    _prev_block = blockchain.database.get_block(prev_block_index)

    raise AxentroException.new("(fast_block::valid?) error finding previous fast block: #{prev_block_index} for current block: #{block.index}") if _prev_block.nil?
    prev_block = _prev_block.not_nil!

    BlockValidator::Rules.rule_fast_signature(block)

    BlockValidator::Rules.rule_network_type(chain_network, block_network)

    BlockValidator::Rules.rule_prev_block_fast_index(doing_replace, blockchain, block.index)

    BlockValidator::Rules.rule_prev_hash(block, prev_block)

    BlockValidator::Rules.rule_fast_transactions(skip_transactions, block.transactions, blockchain, block.index)

    BlockValidator::Rules.rule_timestamp(block.timestamp, prev_block, 30_000_i64)

    BlockValidator::Rules.rule_merkle_tree(block)

    ValidatedBlock.new(true, block)
  rescue e : Axentro::Common::AxentroException
    ValidatedBlock.new(false, block, e.message || "unknown error")
  rescue e : Exception
    error("#{e.class}: #{e.message || "unknown error"}\n#{e.backtrace.join("\n")}")
    ValidatedBlock.new(false, block, "unexpected error: #{e.message || "unknown error"}")
  end

  module Rules
    extend self

    def rule_genesis(block)
      raise AxentroException.new("Invalid Genesis Index: index has to be '0' for genesis block: #{block.index}") if block.index != 0
      raise AxentroException.new("Invalid Genesis Nonce: nonce has to be '0' for genesis block: #{block.nonce}") if block.nonce != "0"
      raise AxentroException.new("Invalid Genesis Previous Hash: prev_hash has to be 'genesis' for genesis block: #{block.prev_hash}") if block.prev_hash != "genesis"
      raise AxentroException.new("Invalid Genesis Difficulty: difficulty has to be '#{Consensus::MINER_DIFFICULTY_TARGET}' for genesis block: #{block.difficulty}") if block.difficulty != Consensus::MINER_DIFFICULTY_TARGET
      raise AxentroException.new("Invalid Genesis Address: address has to be 'genesis' for genesis block") if block.address != "genesis"
    end

    def rule_network_type(chain_network, block_network)
      if chain_network && block_network != chain_network
        raise AxentroException.new("Invalid block network type: incoming block is of type: #{block_network[:name]} but chain is of type: #{chain_network.not_nil![:name]}")
      end
    end

    def rule_prev_block_slow_index(doing_replace, blockchain, current_block_index)
      unless doing_replace
        latest_slow_index = blockchain.database.highest_index_of_kind(BlockKind::SLOW) + 2
        raise AxentroException.new("Index Mismatch: the current block index: #{current_block_index} should match the latest slow block index: #{latest_slow_index}") if current_block_index != latest_slow_index
      