
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
  abstract class TransactionPool
    LIMIT = 2000

    @@instance : TransactionPool? = nil

    @pool : Transactions = Transactions.new
    @pool_locked : Transactions = Transactions.new

    @locked : Bool = false

    alias TxPoolWork = NamedTuple(call: Int32, content: String)

    def self.instance : TransactionPool
      @@instance.not_nil!
    end

    def self.add(transaction : Transaction)
      instance.add(transaction)
    end

    def add(transaction : Transaction)
      if @locked
        @pool_locked << transaction
      else
        insert(transaction)
      end
    end

    def insert(transaction : Transaction)
      index = @pool.index do |t|
        transaction.total_fees > t.total_fees
      end

      @pool.insert(index || @pool.size, transaction)
    end

    def self.clear_all
      instance.clear_all
    end

    def clear_all
      @pool.clear
      @pool_locked.clear
    end

    def self.delete(transaction : Transaction)
      instance.delete(transaction)
    end

    def delete(transaction : Transaction)
      @pool.reject!(&.id.==(transaction.id))
    end

    def self.replace(transactions : Transactions)
      instance.replace(transactions)
    end

    def replace(transactions : Transactions)
      @pool.clear

      transactions.each do |t|
        insert(t)
      end

      @pool_locked.each do |t|
        insert(t)
      end

      @locked = false

      @pool_locked.clear
    end

    def self.all
      instance.all
    end

    def all
      @pool
    end

    def self.embedded
      instance.embedded
    end

    def embedded
      @pool[0..LIMIT - 1]
    end

    def self.lock
      instance.lock
    end

    def lock
      @locked = true
    end

    def self.find(transaction : Transaction)
      instance.find(transaction)
    end

    def find(transaction : Transaction) : Transaction?
      return nil unless found_transaction = @pool.find(&.==(transaction))

      found_transaction.prev_hash = transaction.prev_hash
      found_transaction
    end

    def self.find_all(transactions : Array(Transaction)) : SearchResult
      found = [] of Transaction
      not_found = [] of Transaction
      transactions.each do |transaction|
        if t = find(transaction)
          found << t
        else
          not_found << transaction
        end
      end
      SearchResult.new(found, not_found)
    end

    include Logger
    include TransactionModels
  end

  struct SearchResult
    getter found : Array(Transaction)
    getter not_found : Array(Transaction)

    def initialize(@found : Array(Transaction), @not_found : Array(Transaction))
    end
  end

  class SlowTransactionPool < TransactionPool
    def self.setup
      @@instance ||= SlowTransactionPool.new
    end
  end
end