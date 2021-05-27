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

    BlockValidator::Rules.rule_timestamp(