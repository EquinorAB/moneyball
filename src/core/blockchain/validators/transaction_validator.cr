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

module ::Axentro::Core::TransactionValidator
  extend self

  MESSAGE_SIZE_LIMIT = 512
  TOKEN_SIZE_LIMIT   =  16

  def validate_embedded(transactions : Array(Axentro::Core::Transaction), blockchain : Blockchain, skip_prev_hash_check : Bool = false) : ValidatedTransactions
    vt = ValidatedTransactions.empty

    # (coinbase are validated in validate_coinbase) and are required to pass into dapps (mainly for utxo)
    transactions.select(&.is_coinbase?).each { |tx| vt << tx }

    # only applies to non coinbase transactions and returns all non coinbase transactions
    vt.concat(TransactionValidator::Rules::Sender.rule_sender_mismatches(transactions))

    unless skip_prev_hash_check
      vt.concat(TransactionValidator::Rules::PrevHash.rule_prev_hashes(vt.passed))
    end

    blockchain.dapps.each do |dapp|
      related_transactions = vt.passed.select { |t| dapp.transaction_related?(t.action) }
      if related_transactions.size > 0
        vt.concat(dapp.valid?(related_transactions))
      end
    end

    vt
  end

  def validate_senders(transaction : Axentro::Core::Transaction, network_type : String)
    transaction.senders.each do |sender|
      network = Keys::Address.from(sender.address, "sender").network
      return FailedTransaction.new(transaction, "sender address: #{sender.address} has wrong network type: #{network[:name]}, this node is running as: #{network_type}") if network[:name] != network_type

      public_key = Keys::PublicKey.new(sender.public_key, network)

      if public_key.address.as_hex != sender.address
        return FailedTransaction.new(transaction, "sender public key mismatch - sender public key: #{public_key.as_hex} is not for sender address: #{sender.address}")
      end

      verbose "unsigned_json: #{transaction.as_unsigned.to_json}"
      verbose "unsigned_json_hash: #{transaction.as_unsigned.to_hash}"
      verbose "public key: #{public_key.as_hex}"
      verbose "signature: #{sender.signature}"

      verify_result = KeyUtils.verify_signature(transaction.as_unsigned.to_hash, sender.signature, p