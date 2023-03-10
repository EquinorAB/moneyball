
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
require "../blockchain/*"
require "../blockchain/domain_model/*"
require "../database/*"
require "../database/migrations/*"
require "../modules/logger"

module ::Axentro::Core
  class Database
    getter path : String
    MEMORY        = "%3Amemory%3A"
    SHARED_MEMORY = "%3Amemory%3A%3Fcache%3Dshared"

    @db : DB::Database

    def initialize(@path : String)
      @db = DB.open("sqlite3://#{memory_or_disk(path)}")

      # apply migrations
      mg = MG::Migration.new(@db, tag: "main")
      mg.migrate

      @db.exec "PRAGMA synchronous=OFF"
      @db.exec "PRAGMA cache_size=10000"
      @db.exec "PRAGMA journal_mode=WAL"
    end

    def self.in_memory
      self.new(MEMORY)
    end

    def self.in_shared_memory
      self.new(SHARED_MEMORY)
    end

    private def memory_or_disk(value : String) : String
      if value.starts_with?(MEMORY)
        value
      else
        dir = Path[value].parent.to_s
        FileUtils.mkdir_p(dir) unless File.exists?(dir)
        File.expand_path(value)
      end
    end

    def latest_index : Int64
      idx : Int64? = nil
      @db.query("select idx from blocks order by timestamp desc limit 1") do |rows|
        rows.each do
          idx = rows.read(Int64?)
        end
      end
      debug "database.latest_index: #{idx || 0_i64} "
      idx || 0_i64
    end

    def highest_index_of_kind(kind : BlockKind) : Int64
      idx : Int64? = nil

      @db.query "select max(idx) from blocks where kind = '#{kind}'" do |rows|
        rows.each do
          idx = rows.read(Int64 | Nil)
        end
      end

      idx || 0_i64
    end

    def get_amount_blocks_ontop_of(index : Int64) : Int32
      @db.query_one("select count(*) from blocks where timestamp > (select timestamp from blocks where idx = ?)", index, as: Int32)
    end

    def lowest_index_after_block(index : Int64) : Int64?
      idx : Int64? = nil
      @db.query("select idx from blocks where timestamp > (select timestamp from blocks where idx = ?) order by timestamp desc limit 1", index) do |rows|
        rows.each do
          idx = rows.read(Int64?)
        end
      end
      idx || 0_i64
    end

    def lowest_slow_index_after_block(index : Int64) : Int64?
      idx : Int64? = nil
      @db.query("select idx from blocks where timestamp > (select timestamp from blocks where idx = ?) and kind = ? order by timestamp desc limit 1", index, BlockKind::SLOW.to_s) do |rows|
        rows.each do
          idx = rows.read(Int64?)
        end
      end
      idx || 0_i64
    end

    def chain_network_kind : Core::Node::Network?
      address = nil
      @db.query("select address from blocks where address != 'genesis' limit 1") do |rows|
        rows.each do
          address = rows.read(String)
        end
      end

      if address
        Core::Keys::Address.get_network_from_address(address)
      end
    end

    def total(kind : BlockKind)
      idx : Int64? = nil
      @db.query("select count(*) from blocks where kind = ?", kind.to_s) do |rows|
        rows.each do
          idx = rows.read(Int64 | Nil)
        end
      end
      idx || 0_i64
    end

    def search_domain(term : String) : Bool
      @db.query_one("select count(*) from transactions where message = ? limit 1", term, as: Int32) > 0
    end

    def search_address(term : String) : Bool
      @db.query_one("select count(*) from recipients where address = ? limit 1", term, as: Int32) > 0
    end

    def search_transaction(term : String) : Bool
      @db.query_one("select count(*) from transactions where id like ? || '%' limit 1", term, as: Int32) > 0
    end

    def search_block(term : String) : Bool
      @db.query_one("select count(*) from blocks where idx = ? limit 1", term, as: Int32) > 0
    end

    include Logger
    include Data::Nonces
    include Data::Blocks
    include Data::Rejects
    include Data::Assets
    include Data::Senders
    include Data::Recipients
    include Data::Transactions
  end
end